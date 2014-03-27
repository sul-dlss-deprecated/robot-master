module RobotMaster
  # Maps priority values into priority classes
  module Priority
    # all possible priority classes
    PRIORITIES = %w{critical high default low}.map(&:to_sym)
  
    class << self
      # Converts the given priority number into a priority class
      # 
      # - `:critical` when priority > 100
      # - `:high` when 0 < priority <= 100 
      # - `:default` when priority == 0
      # - `:low` when priority < 0
      #
      # @param [Integer] priority
      # @return [Symbol] the priority class into which the given priority falls
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
  
      # @param [Array<Integer>, Array<Symbol>] priorities
      # @return [Boolean] true if the results queue has any high 
      #   or critical priority items
      #
      # @example
      #    has_priority_items?([0, -1, -1, 0])
      #    => false
      #    has_priority_items?([0, 0, 1])
      #    => true
      #    has_priority_items?([:default, :default, :high])
      #    => true
      def has_priority_items?(priorities)
        priorities.each.any? { |priority|
          unless priority.is_a?(Symbol) or priority.is_a?(Numeric)
            raise ArgumentError, "Illegal priority value #{priority}" 
          end
          [:critical, :high].include?(
            priority.is_a?(Numeric) ?
              priority_class(priority.to_i) :
              priority
            )
        }
      end
  
      # Converts all priority numbers into the possible priority classes.
      #
      # @param [Array<Integer>] priorities
      # @return [Array<Symbol>] a unique array of priority classes into 
      #   which the given priorities fall, in order of highest priority first.
      # @example
      #     priority_classes([1000, 101, 100, -100, -1, 99, 150])
      #     => [:critical, :high, :low]
      def priority_classes(priorities)
        # iterate in high-to-low order on unique priorities
        priorities.uniq.sort.reverse.collect do |priority| 
          priority_class(priority)
        end.uniq
      end
      
    end
  end
end