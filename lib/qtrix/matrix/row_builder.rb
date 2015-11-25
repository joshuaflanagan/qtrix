module Qtrix
  class Matrix
    ##
    # Carries out the construction of rows within the matrix for a number of
    # workers for a specific hostname.
    class RowBuilder
      include Qtrix::Logging
      attr_reader :hostname, :workers, :matrix,
                  :desired_distribution, :heads, :all_entries

      def initialize(matrix, desired_distribution)
        @matrix = matrix
        @desired_distribution = desired_distribution
        @heads = matrix.rows.map{|row| row.entries.first.queue}
        @all_entries = matrix.rows.map(&:entries).flatten
      end

      def build(hostname, workers)
        workers.times.each do
          prioritizer = QueuePrioritizer.new(desired_distribution, heads, all_entries)
          queues_for_row = prioritizer.current_priority_queue
          build_row_for! hostname, queues_for_row
        end
      end

      private

      def build_row_for!(hostname, queues)
        row = Row.new(hostname, [])
        queues.each do |queue|
          build_entry(row, queue, next_val_for(row))
        end
        heads << row.entries[0].queue
        @matrix.add_row(row)
        debug("built row for matrix: #{row}")
      end

      def build_entry(row, queue, entry_val)
        entry = Entry.new(
          queue.name,
          queue.relative_weight,
          entry_val
        )
        all_entries << entry
        row.entries << entry
      end

      # BigDecimal marshalling does not roundtrip in 2.0
      # https://gist.github.com/joshuaflanagan/44a8c4f3d8cf53b24e60
      USE_BIG_DECIMAL = (RUBY_VERSION[0] == "1")

      def next_val_for(row)
        raw_result = 1.0 - sum_of_resource_percentages_for(row.entries)
        if USE_BIG_DECIMAL
          require 'bigdecimal'
          BigDecimal.new(raw_result, 4)
        else
          raw_result.to_f
        end
      end

      def sum_of_resource_percentages_for(entries)
        entries.inject(0) {|memo, entry| memo + entry.resource_percentage}
      end

    end
  end
end
