module Qtrix
  class Override
    extend Qtrix::Logging
    REDIS_KEY = :overrides
    REDIS_CLAIMS_KEY = :override_claims

    class << self
      def add(*args)
        queues, processes = *args
        info("adding #{processes} overrides for #{queues.join(', ')}")
        validate!(processes)
        processes.times do
          Persistence.redis.rpush(REDIS_KEY, queues.join(","))
        end
        Qtrix::Matrix.clear!
      end

      def all
        [].tap do |result|
          raw_list.each_with_index do |queues, index|
            host = Persistence.redis.lindex(REDIS_CLAIMS_KEY, index)
            result << self.new(queues.split(",").map(&:to_sym), host)
          end
        end
      end

      def remove(*args)
        queues, processes = *args
        info("removing #{processes} overrides for #{queues.join(', ')}")
        Persistence.redis.lrem(REDIS_KEY, processes, queues.join(","))
        Qtrix::Matrix.clear!
      end

      def clear!
        clear_claims!
        info("clearing overrides")
        Persistence.redis.del REDIS_KEY
      end

      def clear_claims!
        Qtrix::Matrix.clear!
        debug("clearing overrides claimed")
        Persistence.redis.del(REDIS_CLAIMS_KEY)
      end

      def overrides_for(*args)
        hostname, workers = *args
        needed = unclaimed[0..workers-1].size
        needed.times {Persistence.redis.rpush(REDIS_CLAIMS_KEY, hostname)}
        claimed_by(hostname).map{|override| override.queues}
      end

      private
      def validate!(processes)
        raise "processes must be positive integer" unless processes > 0
      end

      def unclaimed
        all.select{|override| !override.host}
      end

      def claimed_by(hostname)
        all.select{|override| override.host == hostname}
      end

      def raw_list
        Persistence.redis.lrange(REDIS_KEY, 0, -1) 
      end
    end

    attr_reader :queues, :host

    def hash
      @queues.hash ^ @processes.hash
    end

    def eql?(other)
      self.class.equal?(other.class) &&
        @host == other.host &&
        @queues == other.queues
    end
    alias == eql?

    private
    def initialize(queues, host=nil)
      @queues = queues
      @host = host
    end
  end
end
