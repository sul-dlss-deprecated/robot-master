# Single module for all robot master code
module RobotMaster

  # Manages a workflow to enqueue jobs into a priority queue
  class Workflow
    # Perform workflow queueing on the given workflow
    #
    # @param [String] repository
    # @param [String] workflow
    # @return [RobotMaster::Workflow]
    def self.perform(repository, workflow)
      master = RobotMaster::Workflow.new(repository, workflow)
      master.perform
    end

    # @param [String] repository
    # @param [String] workflow
    # @raise [Exception] if cannot read workflow configuration
    def initialize(repository, workflow)
      @repository = repository
      @workflow = workflow
      
      # fetch the workflow object from our configuration cache
      fn = "config/workflows/#{@repository}/#{@workflow}.xml"
      ROBOT_LOG.debug { "Reading #{fn}" }
      @config = begin
        Nokogiri::XML(File.open(fn))
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
        unless process[:prereq].empty? 
          perform_on_process(process)
        else
          # XXX: REST API doesn't return priorities without prereqs
          ROBOT_LOG.warn("Skipping process #{process[:name]} without prereqs")
        end
      end
      self
    end

    # Queries the workflow service for druids waiting for given process step, and 
    # enqueues them to the appropriate priority queue
    #
    # @param [Hash] process
    # @option process [String] :name a fully qualified step name
    # @option process [Array<String>] :prereq fully qualified step names
    # @option process [Integer] :limit maximum number to poll from Workflow service
    # @return [Integer] the number of jobs enqueued
    # @example
    #   perform_on_process(
    #     name: 'dor:assemblyWF:checksum-compute', 
    #     prereq: ['dor:assemblyWF:start-assembly','dor:someOtherWF:other-step']
    #   )
    def perform_on_process(process)
      step = qualify(process[:name])

      ROBOT_LOG.info("Processing #{step}")
      ROBOT_LOG.debug { "depends on #{process[:prereq].join(',')}" }
      
      # fetch pending jobs for this step from the Workflow Service. 
      # we need to always do this to determine whether there are 
      # high priority jobs pending.
      results = Dor::WorkflowService.get_objects_for_workstep(
                  process[:prereq],
                  step, 
                  nil, 
                  nil, 
                  with_priority: true, 
                  limit: process[:limit]
                )
      ROBOT_LOG.debug { "Found #{results.size} druids" }
      return 0 unless results.size > 0
      
      # search the priority queues to determine whether we need to enqueue to them
      needs_work = false
      
      # if we have jobs at a priority level for which the job queue is empty
      Priority.priority_classes(results.values).each do |priority|
        ROBOT_LOG.debug { "Checking priority queue for #{step} #{priority}..." }
        needs_work = true if queue_empty?(step, priority)
      end
      
      # if we have any high priority jobs at all
      needs_work = true if Priority.has_priority_items?(results.values)
      
      ROBOT_LOG.debug { "needs_work=#{needs_work}" }
      return 0 unless needs_work
      
      # perform the mediation
      n = 0
      results.each do |druid, priority|
        begin # XXX preferably within atomic transaction
          enqueue(step, druid, priority_class(priority))
          mark_enqueued(step, druid)
          n += 1
        rescue Exception => e
          ROBOT_LOG.error("Cannot enqueue job: #{step} #{druid} priority=#{priority}: #{e}")
          raise e
        end
      end
      n
    end
    
    # @param [String] step a fully qualified name
    # @param [Symbol, Integer] priority
    # @param [Integer] threshold The number of items below which the queue is considered empty
    # @return [Boolean] true if the queue for the step is "empty"
    def queue_empty?(step, priority, threshold = 100)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      queue = queue_name(step, priority)
      n = Resque.size(queue)
      ROBOT_LOG.debug { "queue size=#{n} #{queue}"}
      (n < threshold)
    end
    
    # Adds the given item to the priority queue for this step
    #
    # Job names for the given step are converted like so:
    #
    # - `dor:assemblyWF:jp2-create` into `Robots::Assembly::Jp2Create`
    # - `dor:etdSubmitWF:binder-transfer` into `Robots:EtdSubmit::BinderTransfer`
    #
    # @param [String] step fully qualified name
    # @param [String] druid
    # @param [Symbol] priority see `priority_class`
    # @return [Hash] returns the `:queue` name and `klass` name enqueued
    def enqueue(step, druid, priority)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      ROBOT_LOG.debug { "enqueue #{step} #{druid} #{priority}" }
      
      # generate the specific priority queue name
      queue = queue_name(step, priority)
      
      # generate the robot job class name
      r, w, s = parse_qualified(step)
      klass = "Robots::#{w.sub('WF', '').camelcase}::#{s.sub('-', '_').camelcase}"
      ROBOT_LOG.debug { "enqueue_to: #{queue} #{klass} #{druid}" }
      
      # perform the enqueue to Resque
      Resque.enqueue_to(queue.to_sym, klass, druid)
      
      { :queue => queue, :klass => klass }
    end
    
    # Updates the status from `waiting` (implied) to `queued` in the Workflow Service
    # 
    # @param [String] step fully qualified name
    # @param [String] druid
    # @return [Symbol] the new status value
    def mark_enqueued(step, druid)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      ROBOT_LOG.debug { "mark_enqueued #{step} #{druid}" }
      
      r, w, s = parse_qualified(step)
      # WorkflowService.update_workflow_status(r, druid, w, s, 'queued')
      :queued
    end

    # Generate the queue name from step and priority
    # 
    # @param [String] step fully qualified name
    # @param [Symbol | Integer] priority
    # @return [String] the queue name
    # @example
    #     queue_name('dor:assemblyWF:jp2-create')
    #     => 'dor_assemblyWF_jp2-create_default'
    #     queue_name('dor:assemblyWF:jp2-create', 100)
    #     => 'dor_assemblyWF_jp2-create_high'
    def queue_name(step, priority = :default)
      [ 
        parse_qualified(qualify(step)),
        priority.is_a?(Integer) ? Priority.priority_class(priority) : priority
      ].flatten.join('_')
    end
    
    protected
    
    # Parses the process XML to extract name and prereqs only.
    # Supports skipping the process using `skip-queue="true"`
    # or `status="completed"` as `process` attributes.
    #
    # @return [Hash] with `:name` and `:prereq` and `:skip` keys
    # @example
    #   parse_process_node '
    #     <workflow-def id="accessionWF" repository="dor">
    #       <process name="remediate-object">
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
    #      :skip => false
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
      
      { :name => name, :prereq => prereqs, :skip => skip }
    end
    
    
    # @param [String] step an unqualified name
    # @return [String] fully qualified name
    # @example
    #   qualify('jp2-create')
    #   => 'dor:assemblyWF:jp2-create'
    #   qualify('dor:assemblyWF:jp2-create')
    #   => 'dor:assemblyWF:jp2-create'
    def qualify(step)
      return step if qualified?(step)
      "#{@repository}:#{@workflow}:#{step}"
    end
    
    # @return [Boolean] true if step is a qualified name, 
    # like dor:assemblyWF:jp2-create
    # @example
    #   qualified?("dor:assemblyWF:jp2-create")
    #   => true
    #   qualified?("jp2-create")
    #   => false
    def qualified?(step)
      (step =~ /:/) == 3
    end
    
    # @return [Array] the repository, workflow, and step values
    # @example
    #   parse_qualified("dor:assemblyWF:jp2-create")
    #   => ['dor', 'assemblyWF', 'jp2-create']
    def parse_qualified(step)
      return [@repository, @workflow, step] unless qualified?(step)
      step.split(/:/, 3)
    end
    
  end
end