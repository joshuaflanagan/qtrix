require 'bigdecimal'
require 'qtrix/matrix/common'

module Qtrix
  module Matrix
    ##
    # Carries out the construction of rows within the matrix for a number of
    # workers for a specific hostname.
    class RowBuilder
      include Qtrix::Namespacing
      include Matrix::Common
      attr_reader :namespace, :hostname, :workers, :matrix,
                  :desired_distribution, :heads, :all_entries

      def initialize(*args)
        @namespace, @hostname, @workers = extract_args(2, *args)
        @matrix = Qtrix::Matrix.fetch(namespace)
        @desired_distribution = Qtrix.desired_distribution(namespace)
        @heads = matrix.map{|row| row.entries.first.queue}
        @all_entries = matrix.map(&:entries).flatten
      end

      def build
        [].tap do |result|
          workers.times.each do
            queues_for_row = queue_prioritizer.current_priority_queue
            build_row_for! hostname, queues_for_row
            result << queues_for_row.map(&:name)
          end
        end
      end

      private
      def queue_prioritizer
        QueuePrioritizer.new(desired_distribution, heads, all_entries)
      end

      def build_row_for!(hostname, queues)
        row = Row.new(hostname, [])
        queues.each do |queue|
          build_entry(row, queue, next_val_for(row))
        end
        heads << row.entries[0].queue
        store(row)
        true
      end

      def build_entry(row, queue, entry_val)
        entry = Entry.new(
          queue.name,
          queue.resource_percentage,
          entry_val
        )
        all_entries << entry
        row.entries << entry
      end

      def next_val_for(row)
        raw_result = 1.0 - sum_of_resource_percentages_for(row.entries)
        BigDecimal.new(raw_result, 4)
      end

      def sum_of_resource_percentages_for(entries)
        entries.inject(0) {|memo, entry| memo += entry.resource_percentage}
      end

      def store(row)
        redis(namespace).rpush(REDIS_KEY, pack(row))
      end
    end
  end
end
