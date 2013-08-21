require 'bigdecimal'

module Orchestrator
  module Matrix
    ##
    # Class responsible for reading & returning the persistent state of
    # the matrix.
    class Reader
      include Namespacing
      include Common

      def self.fetch(namespace=:current)
        redis(namespace).lrange(REDIS_KEY, 0, -1).map{|dump| unpack(dump)}
      end

      def self.to_table(namespace=:current)
        fetch(namespace).map{|row| row.entries.map(&:queue)}
      end

      def self.rows_for_host(hostname, namespace=:current)
        fetch(namespace).select{|row| row.hostname == hostname}
      end
    end
  end
end
