module RobotMaster
  # Manages a workflow to enqueue jobs into a lane queue
  module Queue
    # Generate the queue name from step and lane
    #
    # @param [String] step fully qualified name
    # @param [Symbol | String] lane
    # @return [String] the queue name
    # @example
    #     queue_name('dor:assemblyWF:jp2-create')
    #     => 'dor_assemblyWF_jp2-create_default'
    #     queue_name('dor:assemblyWF:jp2-create', :mylane)
    #     => 'dor_assemblyWF_jp2-create_mylane'
    def self.queue_name(step, lane = :default)
      Workflow.assert_qualified(step)
      unless lane.to_s =~ /^[a-zA-Z0-9-]+$/ || lane.to_s == '*'
        fail ArgumentError, "Invalid lane specification: #{lane}"
      end
      [
        Workflow.parse_qualified(step),
        lane.to_s
      ].flatten.join('_')
    end

    # Counts the number of jobs a queue can accomodate given current workload in the queue
    #
    # @param [String] step a fully qualified name
    # @param [Symbol, String] lane
    # @param [Integer] threshold The number of items below which the queue is considered empty
    # @return [Integer] number of "empty" slots in the queue
    def self.empty_slots(step, lane = :default, threshold = 100)
      Workflow.assert_qualified(step)
      queue = queue_name(step, lane)
      n = Resque.size(queue)
      ROBOT_LOG.debug { "queue size=#{n} #{queue}" }
      n < threshold ? (threshold - n) : 0
    end

    # Adds the given item to the lane queue for this step
    #
    # Job names for the given step are converted like so:
    #
    # - `dor:assemblyWF:jp2-create` into `Robots::DorRepo::Assembly::Jp2Create`
    # - `dor:gisAssemblyWF:start-assembly-workflow` into `Robots::DorRepo::GisAssembly::StartAssemblyWorkflow`
    # - `dor:etdSubmitWF:binder-transfer` into `Robots:DorRepo::EtdSubmit::BinderTransfer`
    #
    # @param [String] step fully qualified name
    # @param [String] druid
    # @param [Symbol | String] lane
    # @param [Hash] opts
    # @option opts [String] :repo_suffix suffix to append to the Repo component of the step name
    # @return [Hash] returns the `:queue` name and `klass` name enqueued
    def self.enqueue(step, druid, lane = :default, _opts = {})
      Workflow.assert_qualified(step)

      # generate the specific lane queue name
      queue = queue_name(step, lane)

      klass = LyberCore::Robot.step_to_classname step

      # perform the enqueue to Resque
      ROBOT_LOG.debug { "enqueue_to: #{queue} #{klass} #{druid}" }
      Resque.enqueue_to(queue.to_sym, klass, druid)

      { queue: queue, klass: klass }
    end
  end
end
