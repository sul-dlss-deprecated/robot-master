module RobotMaster
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).strip
  
  # Manages a workflow to enqueue jobs into a priority queue
  class Workflow
    # Perform workflow queueing on the given workflow
    #
    # @param [String] repository
    # @param [String] workflow
    def self.perform(repository, workflow)
      master = RobotMaster::Workflow.new(repository, workflow)
      master.perform
    end

    # @param [String] repository
    # @param [String] workflow
    def initialize(repository, workflow)
      @repository = repository
      @workflow = workflow
    end

    # Queries the workflow service for all druids awaiting processing, and queues them into a priority queue
    def perform
      doc = Nokogiri::XML(File.open("config/workflows/#{@workflow}.xml"))
      # puts doc.to_xml
      
      # select all process steps that can be in a `waiting` state
      doc.xpath('//process[not(@status) or (@status=\'waiting\')]').each do |node|
        # skip any non-robot steps
        if node['skip-queue'].is_a?(String) and node['skip-queue'].downcase == 'true'
          ROBOT_LOG.debug { "Skipping #{node['name']} as it is marked no-robot" }
          next
        end
        
        # parse out the name and prereqs for this node
        step = parse_process_node(node)
        unless qualified?(step[:name])
          step[:name] = qualify(step[:name])
        end
        # step[:limit] = 100 # XXX: enable for limiting the batches
        
        # doit
        perform_step(step) unless step[:prereq].empty?
      end
    end

    def qualify(step)
      "#{@repository}:#{@workflow}:#{step}"
    end
    
    def qualified?(step)
      step =~ /:/
    end
    
    # Queries the workflow service for druids, and enqueues them to the appropriate priority queue
    #
    # @param [Hash] step
    # @option step [String] :name a fully qualified step name
    # @option step [Array<String>] :prereq
    # @option step [Integer] :limit
    # @example
    #   perform_step({:name => 'dor:assemblyWF:checksum-compute', :prereq => ['dor:assemblyWF:start-assembly']})
    #   => Dor::WorkflowService.get_objects_for_workstep(['dor:assemblyWF:start-assembly'], 'dor:assemblyWF:checksum-compute', 
    #        nil, nil, with_priority: true)
    def perform_step(step)
      raise ArgumentError, "Step must be fully qualified: #{step[:name]}" unless qualified?(step[:name])
      ROBOT_LOG.info("Processing #{step[:name]}")
      ROBOT_LOG.debug { "depends on #{step[:prereq].join(',')}" }
      
      # fetch pending jobs for this step from the Workflow Service. 
      # we need to always do this to determine whether there are high priority jobs pending.
      results = Dor::WorkflowService.get_objects_for_workstep(step[:prereq], step[:name], nil, nil, with_priority: true, limit: step[:limit])
      ap({:results => results})
      ROBOT_LOG.debug { "Found #{results.size} druids" }
      
      # search the priority queues to determine whether we need to enqueue to them
      needs_work = false
      
      # if we have jobs at a priority level for which the job queue is empty
      priority_classes(results.values).each do |priority|
        ROBOT_LOG.debug { "Checking priority queue for #{step[:name]} #{priority}..." }
        needs_work = true if priority_queue_empty?(step[:name], priority)
      end
      
      # if we have any high priority jobs at all
      needs_work = true if has_priority_items?(results)
      
      ROBOT_LOG.debug { "needs_work=#{needs_work}" }
      return unless needs_work
      
      # perform the mediation
      results.each do |druid, priority|
        begin # preferably within atomic transaction
          enqueue(step[:name], druid, priority_class(priority))
          update_status_to_enqueued(step[:name], druid)
        rescue Exception => e
          ROBOT_LOG.error("Cannot enqueue job: #{step[:name]} #{druid} priority=#{priority}: #{e}")
          raise e
        end
      end
    end
    
    # Converts the given priority number into a priority class
    # 
    # - priority > 100 is `:critical`
    # - priority > 0 is `:high`
    # - priority == 0 is `:default`
    # - priority < 0 is `:low`
    #
    # @param [Integer] priority
    # @return [Symbol] the priority class the given priority falls
    def priority_class(priority)
      if priority > 100
        :critical
      elsif priority > 0 and priority <= 100
        :high
      elsif priority < 0
        :low
      else
        :default
      end
    end
    
    protected
    
    # @return [Boolean] true if the results queue has any high priority items
    def has_priority_items?(results)
      results.each_value.any? { |priority| priority > 0 }
    end
    
    # @param [String] step a fully qualified name
    # @param [Symbol] priority `:high`, `:default`, or `:low`
    # @param [Integer] threshold The number of items below which the queue is considered empty
    # @return [Boolean] true if the Resque priority queue for the step needs some more jobs
    #
    # XXX: doesn't handle low-priority cases -- will never fill the low queue unless high and default full
    def priority_queue_empty?(step, priority = :high, threshold = 100)
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
    # @param [Symbol] priority `:high`, `:default`, or `:low`
    # @return [Hash] returns the `:queue` name and `klass` name enqueued
    def enqueue(step, druid, priority)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      ROBOT_LOG.debug { "enqueue #{step} #{druid} #{priority}" }
      queue = queue_name(step, priority)
      r, w, s = unqualify(step)
      klass = "Robots::#{w.sub('WF', '').camelcase}::#{s.sub('-', '_').camelcase}"
      ROBOT_LOG.debug { "enqueue_to: #{queue} #{klass} #{druid}" }
      Resque.enqueue_to(queue.to_sym, klass, druid)
      { :queue => queue, :klass => klass }
    end
    
    # Updates the status from `waiting` (implied) to `queued` in the Workflow Service
    # 
    # @param [String] step fully qualified name
    # @param [String] druid
    def update_status_to_enqueued(step, druid)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      ROBOT_LOG.debug { "update_status_to_enqueued #{step} #{druid}" }
      r, w, s = unqualify(step)
      # raise NotImplementedError # XXX
      # WorkflowService.update_workflow_status(r, druid, w, s, 'queued')
    end

    # Parses the process XML to extract name and prereqs
    #
    # @return [Hash] with `:name` and `:prereq` keys
    # @example
    #   <process name="remediate-object" sequence="6">
    #     <label>Ensure object conforms to latest DOR standards and schemas</label>
    #     <prereq>content-metadata</prereq>
    #     <prereq>descriptive-metadata</prereq>
    #     <prereq>technical-metadata</prereq>
    #     <prereq>rights-metadata</prereq>
    #   </process>
    # 
    #   => {
    #     :name => 'remediate-object',
    #     :prereq => [
    #         'content-metadata',
    #         'descriptive-metadata',
    #         'technical-metadata',
    #         'rights-metadata'
    #      ]
    #   }
    # 
    def parse_process_node(node)
      step = node['name']
      prereqs = []
      node.xpath('prereq').each do |prereq|
        qualified_prereq = prereq.text
        unless qualified?(qualified_prereq)
          qualified_prereq = "#{@repository}:#{@workflow}:#{qualified_prereq}"
        end
        prereqs << qualified_prereq
      end
      { :name => step, :prereq => prereqs }
    end
        
    # Converts all priority numbers into the possible priority classes.
    #
    # @param [Array<Integer>] priorities
    # @return [Array<Symbol>] a unique array of priority classes into which the given priorities fall,
    #   in order of highest priority first.
    # @example
    #     priority_classes([1000, 101, 100, -100, -1, 99, 150])
    #     => [:critical, :high, :low]
    def priority_classes(priorities)
      priorities.uniq.sort.collect {|priority| priority_class(priority) }.uniq
    end
    
    def unqualify(step)
      step.split(/:/, 3)
    end
    
    # Constructs the Resque priority queue name
    # 
    # @param [String] step fully qualified name
    # @param [Symbol | Integer] priority
    # @return [String] the Resque queue name of the form: `repo_myWF_my-step_priority`
    def queue_name(step, priority)
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      r, w, s = unqualify(step)
      [ 
        r, 
        w, 
        s, 
        priority.is_a?(Integer) ? priority_class(priority) : priority
      ].join('_')
    end
  end
end