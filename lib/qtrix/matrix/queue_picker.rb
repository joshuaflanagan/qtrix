require 'bigdecimal'

module Qtrix
  module Matrix
    ##
    # Responsible for picking a number of queue lists from the matrix
    # for a specific host.  Will return already picked lists if they
    # exist.  Will generate new queue lists if they are needed and
    # prune old lists as they are no longer needed, maintaining a row
    # in the matrix for the number of workers for the host.
    class QueuePicker
      include Namespacing
      include Common
      include Logging
      attr_reader :namespace, :reader, :hostname, :workers

      def initialize(*args)
        @namespace, @reader, @hostname, @workers = extract_args(3, *args)
      end

      def pick!
        delta = workers - rows_for_host.size
        new_queues = []
        if delta > 0
          generate(delta)
        elsif delta < 0
          prune(delta)
        end
        rows_for_host.map(&to_queues).tap do |rows|
          debug("matrix rows for #{hostname}: #{rows}")
        end
      end

      private
      def to_queues
        lambda {|row| row.entries.map(&:queue)}
      end

      def rows_for_host
        reader.rows_for_host(hostname, namespace)
      end

      def generate(count)
        RowBuilder.new(namespace, hostname, count).build
      end

      def prune(count)
        count.abs.times.each do
          row = rows_for_host.pop
          debug("pruning from matrix: #{row}")
          redis(namespace).lrem(REDIS_KEY, -2, pack(row))
        end
      end
    end
  end
end
