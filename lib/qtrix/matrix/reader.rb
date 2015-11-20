require 'bigdecimal'

module Qtrix
  module Matrix
    ##
    # Class responsible for reading & returning the persistent state of
    # the matrix.
    class Reader
      include Common

      def self.fetch
        Persistence.redis.lrange(REDIS_KEY, 0, -1).map{|dump| unpack(dump)}
      end

      def self.to_table
        fetch.map{|row| row.entries.map(&:queue)}
      end

      def self.rows_for_host(hostname)
        fetch.select{|row| row.hostname == hostname}
      end
    end
  end
end
