# Single module for all robot master code
module RobotMaster
  # e.g., `VERSION => '1.2.3'`
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

    # Queries the workflow service for all druids awaiting processing, and 
    # queues them into a priority queue
    def perform
      # fetch the workflow object from our configuration cache
      doc = Nokogiri::XML(File.open("config/workflows/#{@workflow}.xml"))
      
      # select all process steps that can be in a `waiting` state
      doc.xpath('//process[not(@status) or (@status=\'waiting\')]').each do |node|        
        # parse out the name and prereqs for this node
        process = parse_process_node(node)
        # process[:limit] = 100 # XXX: enable for limiting the batches
        
        # skip any processes that do not require queueing
        if process[:skip]
          ROBOT_LOG.debug { "Skipping #{process[:name]}" }
          next
        end
        
        # doit
        unless process[:prereq].empty? 
          # XXX: REST API doesn't return priorities without prereqs
          enqueue_process(process) 
        end
      end
      nil
    end

    # Queries the workflow service for druids waiting for given process step, and 
    # enqueues them to the appropriate priority queue
    #
    # @param [Hash] process
    # @option process [String] :name a fully qualified step name
    # @option process [Array<String>] :prereq fully qualified step names
    # @option process [Integer] :limit maximum number of jobs to enqueued
    # @return [Integer] the number of jobs enqueued
    # @example
    #   enqueue_process(
    #     name: 'dor:assemblyWF:checksum-compute', 
    #     prereq: ['dor:assemblyWF:start-assembly', 'dor:someOtherWF:other-step']
    #   )
    def enqueue_process(process)
      step = process[:name]
      raise ArgumentError, "Step must be fully qualified: #{step}" unless qualified?(step)
      ROBOT_LOG.info("Processing #{step}")
      ROBOT_LOG.debug { "depends on #{process[:prereq].join(',')}" }
      
      # fetch pending jobs for this step from the Workflow Service. 
      # we need to always do this to determine whether there are high priority jobs pending.
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
      priority_classes(results.values).each do |priority|
        ROBOT_LOG.debug { "Checking priority queue for #{step} #{priority}..." }
        needs_work = true if priority_queue_empty?(step, priority)
      end
      
      # if we have any high priority jobs at all
      needs_work = true if has_priority_items?(results.values)
      
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
    
    # @param [Array] priorities
    # @return [Boolean] true if the results queue has any high priority items
    def has_priority_items?(priorities)
      priorities.each.any? { |priority| priority > 0 }
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

    # Parses the process XML to extract name and prereqs
    #
    # @return [Hash] with `:name` and `:prereq` and `:skip` keys
    # @example
    #   parse_process_node '
    #     <workflow-def id="accessionWF" repository="dor">
    #       <process name="remediate-object" sequence="6">
    #         <label>Ensure object conforms to latest DOR standards and schemas</label>
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
      name = node['name']
      name = qualify(name) unless qualified?(name)
      skip = false
      if (node['skip-queue'].is_a?(String) and 
          node['skip-queue'].downcase == 'true') or
         (node['status'].is_a?(String) and 
          node['status'].downcase != 'waiting')
        skip = true
      end

      prereqs = []
      node.xpath('prereq').each do |prereq|
        qualified_prereq = prereq.text
        unless qualified?(qualified_prereq)
          qualified_prereq = "#{@repository}:#{@workflow}:#{qualified_prereq}"
        end
        prereqs << qualified_prereq
      end
      { :name => name, :prereq => prereqs, :skip => skip }
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
      priorities.uniq.sort.reverse.collect {|priority| priority_class(priority) }.uniq
    end
    
    # Constructs the Resque priority queue name
    # 
    # @param [String] step fully qualified name
    # @param [Symbol | Integer] priority
    # @return [String] the Resque queue name of the form: `repo_myWF_my-step_priority`
    def queue_name(step, priority)
      step = qualify(step) unless qualified?(step)
      r, w, s = parse_qualified(step)
      [ 
        r, 
        w, 
        s, 
        priority.is_a?(Integer) ? priority_class(priority) : priority
      ].join('_')
    end
    
    protected
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
      step =~ /:/
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