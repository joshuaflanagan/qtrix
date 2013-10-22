module Qtrix
  class Override
    extend Qtrix::Namespacing
    extend Qtrix::Logging
    REDIS_KEY = :overrides
    REDIS_CLAIMS_KEY = :override_claims

    class << self
      def add(*args)
        namespace, queues, processes = extract_args(2, *args)
        info("adding #{processes} overrides for #{queues.join(', ')} to #{namespace}")
        validate!(processes)
        processes.times do
          redis(namespace).rpush(REDIS_KEY, queues.join(","))
        end
        Qtrix::Matrix.clear!(namespace)
      end

      def all(ns=:current)
        [].tap do |result|
          raw_list(ns).each_with_index do |queues, index|
            host = redis(ns).lindex(REDIS_CLAIMS_KEY, index)
            result << self.new(queues.split(",").map(&:to_sym), host)
          end
        end
      end

      def remove(*args)
        namespace, queues, processes = extract_args(2, *args)
        info("removing #{processes} overrides for #{queues.join(', ')} to #{namespace}")
        redis(namespace).lrem(REDIS_KEY, processes, queues.join(","))
        Qtrix::Matrix.clear!(namespace)
      end

      def clear!(namespace=:current)
        clear_claims!(namespace)
        info("clearing overrides for #{namespace}")
        redis(namespace).del REDIS_KEY
      end

      def clear_claims!(namespace=:current)
        Qtrix::Matrix.clear!(namespace)
        debug("clearing overrides claimed for #{namespace}")
        redis(namespace).del(REDIS_CLAIMS_KEY)
      end

      def overrides_for(*args)
        namespace, hostname, workers = extract_args(2, *args)
        needed = unclaimed(namespace)[0..workers-1].size
        needed.times {redis(namespace).rpush(REDIS_CLAIMS_KEY, hostname)}
        claimed_by(namespace, hostname).map{|override| override.queues}
      end

      private
      def validate!(processes)
        raise "processes must be positive integer" unless processes > 0
      end

      def unclaimed(namespace)
        all(namespace).select{|override| !override.host}
      end

      def claimed_by(*args)
        namespace, hostname = extract_args(1, *args)
        all(namespace).select{|override| override.host == hostname}
      end

      def raw_list(ns=:current)
        redis(ns).lrange(REDIS_KEY, 0, -1) 
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
