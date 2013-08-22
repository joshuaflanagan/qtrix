module Qtrix
  module Matrix
    ##
    # Utility class to examining the distribution of queues
    # within a matrix.  Its operations result in a hash of
    # queue names mapped to arrays containing counts that
    # the queue appeared in that column index of the matrix.
    module Analyzer
      # Breaks down any old matrix
      def self.breakdown(matrix)
        result_hash_for(matrix).tap do |result|
          matrix.each do |row|
            row.each_with_index do |queue, column|
              result[queue][column] += 1
            end
          end

          def result.to_s
            self.map{|queue, pos| "#{queue}: #{pos.join(',')}"}.join("\n")
          end

          def result.dump
            puts self
          end
        end
      end

      ##
      # Maps the specified queue weights, generates a matrix
      # with the specified number of rows, then breaks it down
      # as above.
      def self.analyze!(rows, queue_weights={})
        Qtrix::Matrix.clear!
        Qtrix::Queue.clear!
        Qtrix::Queue.map_queue_weights(queue_weights)
        Qtrix::Matrix.fetch_queues(`hostname`, rows)
        breakdown(Qtrix::Matrix.to_table)
      end

      private
      def self.result_hash_for(matrix)
        Hash.new{|h, k| h[k] = [0] * matrix.first.size}
      end
    end
  end
end
