require 'bigdecimal'
require 'qtrix/matrix/common'

module Qtrix
  module Matrix
    ##
    # Maintains current prioritization of queues based on the
    # state of all rows in the matrix.

    class QueuePrioritizer
      attr_reader :desired_distribution, :heads, :all_entries

      def initialize(desired_distribution, heads, all_entries)
        @desired_distribution = desired_distribution
        @heads = heads
        @all_entries = all_entries
        @new_head_picked = false
      end

      def current_priority_queue
        # Not a true priority queue, since we are sorting after all elements
        # are inserted
        queue = queue_priority_tuples_from desired_distribution
        prioritized_queue = queue.sort &by_priority_of_tuple
        to_simple_queues_from prioritized_queue
      end

      def queue_priority_tuples_from(dist)
        dist.map{|queue| [queue, current_priority_of(queue)]}
      end

      def by_priority_of_tuple
        lambda {|i, j| j[1] <=> i[1]}
      end

      def to_simple_queues_from(prioritized_queue)
        prioritized_queue.map {|tuple| tuple[0]}
      end

      def current_priority_of(queue)
        if has_appeared_at_head_of_row?(queue.name) || @new_head_picked
          normal_priority_for queue
        else
          @new_head_picked = true
          starting_priority_for queue
        end
      end

      def has_appeared_at_head_of_row?(queue_name)
        heads.include?(queue_name)
      end

      def normal_priority_for(queue)
        queue.resource_percentage / (1 + sum_of(entries_for(queue)))
      end

      def starting_priority_for(queue)
        queue.resource_percentage * 10000
      end

      def sum_of(entries)
        entries.inject(0) {|memo, e| memo += e.value}
      end

      def entries_for(queue)
         all_entries.select{|entry| entry.queue == queue.name}
      end
    end
  end
end
