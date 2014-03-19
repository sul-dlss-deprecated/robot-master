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
        unless node['no-robot'].nil?
          ROBOT_LOG.debug { "Skipping #{node['name']} as it is marked no-robot" }
          next
        end
        
        # parse out the name and prereqs for this node
        step = parse_process_node(node)
        # step[:limit] = 100 # XXX: enable for limiting the batches
        
        # doit
        perform_step(step) unless step[:prereq].empty?
      end
    end
    
    # Queries the workflow service for druids, and enqueues them to the appropriate priority queue
    #
    # @param step [Hash]
    # @option step [String] :name
    # @option step [Array<String>] :prereq
    # @example
    #   perform_step({:name => 'checksum-compute', :prereq => ['start-assembly']})
    #   => Dor::WorkflowService.get_objects_for_workstep(['start-assembly'], 'checksum-compute', @repository, @workflow, true)
    def perform_step(step)
      ROBOT_LOG.info("Processing #{@repository}:#{@workflow}:#{step[:name]}")
      ROBOT_LOG.debug { "depends on #{step[:prereq].join(',')}" }
      
      # fetch pending jobs for this step from the Workflow Service. 
      # we need to always do this to determine whether there are high priority jobs pending.
      results = Dor::WorkflowService.get_objects_for_workstep(step[:prereq], step[:name], @repository, @workflow, true, step[:limit])
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
        enqueue(step[:name], druid, priority_class(priority))
        update_status_to_enqueued(step[:name], druid)
      end
    end
    
    protected
    
    # @return [Boolean] true if the results queue has any high priority items
    def has_priority_items?(results)
      results.each_value.any? { |priority| priority > 0 }
    end
    
    # @param [String] step
    # @param [Symbol] priority `:high`, `:default`, or `:low`
    # @param [Integer] threshold The number of items below which the queue is considered empty
    # @return [Boolean] true if the Resque priority queue for the step needs some more jobs
    #
    # XXX: doesn't handle low-priority cases -- will never fill the low queue unless high and default full
    def priority_queue_empty?(step, priority = :high, threshold = 100)
      queue = "prod_#{@workflow}_#{step}_#{priority}" # XXX: needs to come from environment
      n = Resque.size(queue)
      ROBOT_LOG.debug { "queue size=#{n} #{queue}"}
      (n < threshold)
    end
    
    # Adds the given item to the priority queue for this step
    #
    # @param [String] step name of the step
    # @param [String] druid
    # @param [Symbol] priority `:high`, `:default`, or `:low`
    def enqueue(step, druid, priority)
      ROBOT_LOG.debug { "enqueue #{step} #{druid} #{priority}" }
      # raise NotImplementedError # XXX
    end
    
    # Updates the status from `waiting` (implied) to `queued` in the Workflow Service
    # 
    # @param [String] step name of the step
    # @param [String] druid
    def update_status_to_enqueued(step, druid)
      ROBOT_LOG.debug { "update_status_to_enqueued #{step} #{druid}" }
      # raise NotImplementedError # XXX
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
        prereqs << prereq.text
      end
      { :name => step, :prereq => prereqs }
    end
    
    # @param [Integer] priority where 0 is default, positive is high, and negative is low
    # @return [Symbol] one of `:high`, `:default`, `:low` keys for into which class the given priority falls
    def priority_class(priority)
      if priority > 0
        :high
      elsif priority < 0
        :low
      else
        :default
      end
    end
    
    # @return [Array<Symbol>] contains `:high`, `:default`, `:low` keys for into which classes the 
    #   given priorities fall
    def priority_classes(priorities)
      priorities.uniq.collect {|priority| priority_class(priority) }.uniq
    end
  end
end