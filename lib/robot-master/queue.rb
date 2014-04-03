module RobotMaster
  # Manages a workflow to enqueue jobs into a priority queue
  module Queue
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
    def self.queue_name(step, priority = :default)
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
    def self.needs_work?(step, priority = :default, threshold = 100)
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
    # - `dor:assemblyWF:jp2-create` into `Robots::DorRepo::Assembly::Jp2Create`
    # - `dor:etdSubmitWF:binder-transfer` into `Robots:DorRepo::EtdSubmit::BinderTransfer`
    #
    # @param [String] step fully qualified name
    # @param [String] druid
    # @param [Symbol] priority see `priority_class`
    # @param [Hash] opts
    # @option opts [String] :repo_suffix suffix to append to the Repo component of the step name
    # @return [Hash] returns the `:queue` name and `klass` name enqueued
    def self.enqueue(step, druid, priority, opts = {})
      Workflow.assert_qualified(step)
  
      # generate the specific priority queue name
      queue = queue_name(step, priority)
  
      # generate the robot job class name
      opts[:repo_suffix] ||= 'Repo'
      r, w, s = Workflow.parse_qualified(step)
      klass = [
        'Robots',
        r.camelcase + opts[:repo_suffix], # 'Dor' conflicts with dor-services
        w.sub('WF', '').camelcase,
        s.sub('-', '_').camelcase
      ].join('::')
  
      # perform the enqueue to Resque
      ROBOT_LOG.debug { "enqueue_to: #{queue} #{klass} #{druid}" }
      Resque.enqueue_to(queue.to_sym, klass, druid)
  
      { :queue => queue, :klass => klass }
    end
  end
end