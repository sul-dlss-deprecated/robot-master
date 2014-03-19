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
            
      results = Dor::WorkflowService.get_objects_for_workstep(step[:prereq], step[:name], @repository, @workflow, true, step[:limit])
      ap({:results => results})
      ROBOT_LOG.debug { "Found #{results.size} druids" }
      
      return unless has_priority_items?(results) or priority_queue_empty?(step)
      
      results.each do |druid, priority|
        enqueue(step[:name], druid, priority)
        update_status_to_enqueued(step[:name], druid)
      end
    end
    
    protected
    
    # @return [Boolean] true if the results queue has any high priority items
    def has_priority_items?(results)
      results.each_value.any? {|priority| priority > 0 }
    end
    
    # @return [Boolean] true if the Resque priority queue for the step needs some more jobs
    def priority_queue_empty?(step)
      # raise NotImplementedError
      %w{high default low}.each do |priority|
        queue = "#{ENV['ROBOT_ENVIRONMENT']}_#{@workflow}_#{step[:name]}_#{priority}"
        # puts queue
      end
      true # XXX
    end
    
    # Adds the given item to the priority queue for this step
    #
    # @param [String] step name of the step
    # @param [String] druid
    # @param [Integer] priority
    def enqueue(step, druid, priority)
      raise NotImplementedError
    end
    
    # Updates the status from `waiting` (implied) to `queued` in the Workflow Service
    # 
    # @param [String] step name of the step
    # @param [String] druid
    def update_status_to_enqueued(step, druid)
      raise NotImplementedError
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
  end
end