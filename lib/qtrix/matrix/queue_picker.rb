require 'bigdecimal'

module Qtrix
  class Matrix
    ##
    # Responsible for picking a number of queue lists from the matrix
    # for a specific host.  Will return already picked lists if they
    # exist.  Will generate new queue lists if they are needed and
    # prune old lists as they are no longer needed, maintaining a row
    # in the matrix for the number of workers for the host.
    class QueuePicker
      include Logging

      def initialize(matrix, desired_distribution)
        @matrix = matrix
        @desired_distribution = desired_distribution
      end

      def modify_matrix_to_satisfy_request(hostname, num_rows_requested)
        delta = num_rows_requested - @matrix.rows_for_host(hostname).size
        if delta > 0
          generate(hostname, delta)
        elsif delta < 0
          prune(hostname, delta)
        end
        @matrix.rows_for_host(hostname).map(&to_queues).tap do |rows|
          debug("matrix rows for #{hostname}: #{rows}")
        end
      end

      private
      def to_queues
        lambda {|row| row.entries.map(&:queue)}
      end

      def generate(hostname, count)
        row_builder = RowBuilder.new(@matrix, @desired_distribution)
        row_builder.build(hostname, count)
      end

      def prune(hostname, count)
        count.abs.times.each do
          removed_row = @matrix.remove_row_for_host(hostname)
          debug("pruning from matrix: #{removed_row}")
        end
      end
    end
  end
end
