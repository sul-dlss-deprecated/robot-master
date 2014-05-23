module RobotMaster

  # Manages a workflow to enqueue jobs into a priority queue
  class Workflow
    QUEUE_LIMIT_DEFAULT = 100
    attr_reader :repository, :workflow, :config
        
    # Perform workflow queueing on the given workflow
    #
    # @param [String] repository
    # @param [String] workflow
    # @return [RobotMaster::Workflow]
    def self.perform(repository, workflow)
      start = Time.now
      ROBOT_LOG.debug { "Start Workflow.perform(#{repository}, #{workflow})" }
      master = new(repository, workflow)
      master.perform
      ROBOT_LOG.debug { "Finished Workflow.perform(#{repository}, #{workflow}): #{Time.now - start} seconds" }
    end

    # @return [Boolean] true if step is a qualified name, 
    # like dor:assemblyWF:jp2-create
    # @example
    #   qualified?("dor:assemblyWF:jp2-create")
    #   => true
    #   qualified?("jp2-create")
    #   => false
    def self.qualified?(step)
      /^\w+:\w+:[\w\-]+$/ === step
    end
    
    # @param [String] step fully qualified step name
    # @raise [ArgumentError] if `step` is not fully qualified
    def self.assert_qualified(step)
      raise ArgumentError, "step not qualified: #{step}" unless qualified?(step)
    end

    # @param [String] step fully qualified step name
    # @return [Array] the repository, workflow, and step values
    # @example
    #   parse_qualified("dor:assemblyWF:jp2-create")
    #   => ['dor', 'assemblyWF', 'jp2-create']
    def self.parse_qualified(step)
      assert_qualified(step)
      step.split(/:/, 3)
    end
    
    # @param [String] repository
    # @param [String] workflow
    # @param [String] workflow definition XML
    # @raise [Exception] if cannot read workflow configuration
    def initialize(repository, workflow, xml = nil)
      @repository = repository
      @workflow = workflow
      
      # fetch the workflow object from our configuration cache
      if xml.nil?
        fn = "config/workflows/#{@repository}/#{@workflow}.xml"
        ROBOT_LOG.debug { "Reading #{fn}" }
        xml = File.read(fn)
      end
      @config = begin
        Nokogiri::XML(xml)
      rescue Exception => e
        ROBOT_LOG.error("Cannot load workflow object: #{fn}")
        raise e
      end
    end

    # Queries the workflow service for all druids awaiting processing, and 
    # queues them into a priority queue.
    # @return [RobotMaster::Workflow] self
    def perform      
      # perform on each process step
      @config.xpath('//process').each do |node|        
        process = parse_process_node(node)
        
        # skip any processes that do not require queueing
        if process[:skip]
          ROBOT_LOG.debug { "Skipping #{process[:name]}" }
          next
        end
        
        # doit
        (n, lanes) = perform_on_process(process)
        ROBOT_LOG.info("Queued #{n} jobs across #{lanes.size} lanes for #{process[:name]}") if n > 0
      end
      self
    end    
    
    protected
    # Updates the status from `waiting` (implied) to `queued` in the Workflow Service
    # 
    # @param [String] step fully qualified name
    # @param [String] druid
    # @return [String] the new status value
    # @raise [Exception] if the workflow service cannot update status due to
    #     invalid state transition
    def mark_enqueued(step, druid, mark_status = 'queued')
      Workflow.assert_qualified(step)
      ROBOT_LOG.debug { "mark_enqueued #{step} #{druid} #{mark_status}" }
  
      r, w, s = Workflow.parse_qualified(step)
      begin
        if ENV['ROBOT_MASTER_ENABLE_UPDATE_WORKFLOW_STATUS'] == 'yes'
          Dor::WorkflowService.update_workflow_status(r, druid, w, s, mark_status.to_s, expected: 'waiting')
        end
      rescue => e
        ROBOT_LOG.warn("Update workflow status failed for waiting->queued transition: #{e}")
        raise e
      end
      mark_status
    end

    # Queries the workflow service for druids waiting for given process step, and 
    # enqueues them to the appropriate priority queue
    #
    # R is the set of robots
    # foreach r in R
    #   n is queue-limit(r), the limit for the given robot queues (defaults to 100)
    #   L is the set of WorkflowService.lanes(r)
    #   foreach l in L
    #     J is the set of WorkflowService.jobs(r, l, n)
    #     Q is the queue(r, l)
    #     foreach j in J
    #       while n is greater than |Q|
    #          add j to Q
    #       end
    #     end
    #   end
    # end
    #
    # @param [Hash] process
    # @option process [String] :name a fully qualified step name
    # @option process [Array<String>] :prereq fully qualified step names
    # @option process [Integer] :limit maximum number to poll from Workflow service (defaults to 100)
    # @return [Integer] the number of jobs enqueued
    # @example
    #   perform_on_process(
    #     name: 'dor:assemblyWF:checksum-compute', 
    #     prereq: ['dor:assemblyWF:start-assembly','dor:someOtherWF:other-step'],
    #     limit: 100
    #   )
    def perform_on_process(process)
      step = process[:name]
      self.class.assert_qualified(step)
      process[:limit] ||= QUEUE_LIMIT_DEFAULT

      ROBOT_LOG.info("Processing #{step}")
      ROBOT_LOG.debug { "-- depends on #{process[:prereq].join(',')}" }
      
      # fetch pending jobs in all lanes for this step from the Workflow Service. 
      n = 0
      lanes = Dor::WorkflowService.get_lane_ids(*(step.split(/:/)))
      lanes.each do |lane|
        # only fetch the minimum results we'll need
        # Note that we assume no robots working on the queue and robot-master runs periodically
        nlimit = [process[:limit], Queue.empty_slots(step, lane, process[:limit])].min
        next unless nlimit > 0
        
        results = Dor::WorkflowService.get_objects_for_workstep(
                    process[:prereq],
                    step,
                    lane,
                    limit: nlimit
                  )
        ROBOT_LOG.debug { "Found #{results.size} druids ready in lane #{lane}: limited to #{nlimit}" }
              
        # perform the mediation for this lane
        results.each do |druid|
          if Queue.empty_slots(step, lane, process[:limit]) > 0 # double check
            begin # XXX preferably within atomic transaction
              mark_enqueued(step, druid)
              Queue.enqueue(step, druid, lane)
              n += 1
            rescue => e
              ROBOT_LOG.warn("Cannot enqueue job: #{step} #{druid} #{lane}: #{e}")
              # continue to the next job
            end
          end
        end
      end
      [n, lanes]
    end
        
    # Parses the process XML to extract name and prereqs only.
    # Supports skipping the process using `skip-queue="true"`
    # or `status="completed"` as `process` attributes.
    # Support limiting queueing with `queue-limit` attribute.
    #
    # @return [Hash] with `:name` and `:prereq` and `:skip` and `:limit` keys
    # @example
    #   parse_process_node '
    #     <workflow-def id="accessionWF" repository="dor">
    #       <process name="remediate-object" queue-limit="123">
    #         <prereq>content-metadata</prereq>
    #         <prereq>descriptive-metadata</prereq>
    #         <prereq>technical-metadata</prereq>
    #         <prereq>rights-metadata</prereq>
    #       </process>
    #     </workflow-def>
    #   ')
    #   => {
    #     :name => 'dor:accessionWF:remediate-object',
    #     :prereq => [
    #         'dor:accessionWF:content-metadata',
    #         'dor:accessionWF:descriptive-metadata',
    #         'dor:accessionWF:technical-metadata',
    #         'dor:accessionWF:rights-metadata'
    #      ],
    #      :skip => false,
    #      :limit => 123
    #   }
    # 
    def parse_process_node(node)
      # extract fully qualified process name
      name = qualify(node['name'])
      
      # may skip with skip-queue=true or status=completed|hold|...
      skip = false
      if (node['skip-queue'].is_a?(String) and 
          node['skip-queue'].downcase == 'true') or
         (node['status'].is_a?(String) and 
          node['status'].downcase != 'waiting')
        skip = true
      end

      # ensure all prereqs are fully qualified
      prereqs = node.xpath('prereq').collect do |prereq|
        qualify(prereq.text)
      end
      
      { 
        :name => name, 
        :prereq => prereqs, 
        :skip => skip,
        :limit => (node['queue-limit'] ? node['queue-limit'].to_i : nil )
      }
    end
    
    
    # @param [String] step an unqualified name
    # @return [String] fully qualified name
    # @example
    #   qualify('jp2-create')
    #   => 'dor:assemblyWF:jp2-create'
    #   qualify('dor:assemblyWF:jp2-create')
    #   => 'dor:assemblyWF:jp2-create'
    def qualify(step)
      if self.class.qualified?(step)
        step
      else
        "#{@repository}:#{@workflow}:#{step}"
      end
    end
    
  end
end