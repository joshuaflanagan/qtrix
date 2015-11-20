require 'bigdecimal'

module Qtrix
  class Matrix
    ##
    # Class responsible for reading & returning the persistent state of
    # the matrix.
    class Reader
      include Common

      def initialize(redis)
        @redis = redis
      end

      def fetch
        @redis.lrange(REDIS_KEY, 0, -1).map{|dump| unpack(dump)}
      end

      def to_table
        fetch.map{|row| row.entries.map(&:queue)}
      end

      def rows_for_host(hostname)
        fetch.select{|row| row.hostname == hostname}
      end
    end
  end
end
