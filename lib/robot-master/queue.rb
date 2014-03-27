module RobotMaster
  # Manages a workflow to enqueue jobs into a priority queue
  module Queue
    class << self
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
        Workflow.assert_qualified(step)
        unless priority.is_a?(Integer) or Priority::PRIORITIES.include?(priority)
          raise ArgumentError, "Unknown priority: #{priority}"
        end
        [ 
          Workflow.parse_qualified(step),
          priority.is_a?(Integer) ? Priority.priority_class(priority) : priority
        ].flatten.join('_')
      end
  
      # @param [String] step a fully qualified name
      # @param [Symbol, Integer] priority
      # @param [Integer] threshold The number of items below which the queue is considered empty
      # @return [Boolean] true if the queue for the step is "empty"
      def queue_empty?(step, priority, threshold = 100)
        Workflow.assert_qualified(step)
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
        Workflow.assert_qualified(step)
        ROBOT_LOG.debug { "enqueue #{step} #{druid} #{priority}" }
    
        # generate the specific priority queue name
        queue = queue_name(step, priority)
    
        # generate the robot job class name
        r, w, s = Workflow.parse_qualified(step)
        klass = "Robots::#{r.camelcase}::#{w.sub('WF', '').camelcase}::#{s.sub('-', '_').camelcase}"
        ROBOT_LOG.debug { "enqueue_to: #{queue} #{klass} #{druid}" }
    
        # perform the enqueue to Resque
        Resque.enqueue_to(queue.to_sym, klass, druid)
    
        { :queue => queue, :klass => klass }
      end
    end
  end
end