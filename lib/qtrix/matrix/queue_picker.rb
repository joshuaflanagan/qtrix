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
      include Common
      include Logging

      def initialize(matrix, reader, redis)
        @matrix = matrix
        @reader = reader
        @redis = redis
      end

      def pick!(hostname, workers)
        delta = workers - rows_for_host(hostname).size
        if delta > 0
          generate(hostname, delta)
        elsif delta < 0
          prune(hostname, delta)
        end
        rows_for_host(hostname).map(&to_queues).tap do |rows|
          debug("matrix rows for #{hostname}: #{rows}")
        end
      end

      private
      def to_queues
        lambda {|row| row.entries.map(&:queue)}
      end

      def rows_for_host(hostname)
        @reader.rows_for_host(hostname)
      end

      def generate(hostname, count)
        row_builder = RowBuilder.new(@redis, @matrix.fetch, Qtrix.desired_distribution)
        row_builder.build(hostname, count)
      end

      def prune(hostname, count)
        count.abs.times.each do
          row = rows_for_host(hostname).pop
          debug("pruning from matrix: #{row}")
          @redis.lrem(REDIS_KEY, -2, pack(row))
        end
      end
    end
  end
end
