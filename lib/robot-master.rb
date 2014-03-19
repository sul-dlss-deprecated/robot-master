module RobotMaster
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).strip
  
  class Workflow
    # main entry point
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
        # step[:limit] = 100
        
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
      
      return unless has_priority_items?(results) or not queue_needs_work?(step)
      
      results.each do |item, priority|
        enqueue(item, priority)
        mark_as_queued(item)
      end
    end
    
    private
    
    def has_priority_items?(results)
      results.each_value.any? {|priority| priority > 0 }
    end
    
    def queue_needs_work?(step)
      true # XXX
      # raise NotImplementedError
    end
    
    
    def enqueue(item, priority)
      raise NotImplementedError
    end
    
    def mark_as_queued(item)
      raise NotImplementedError
    end

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