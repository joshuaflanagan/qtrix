module Qtrix
  class OverrideStore
    include Qtrix::Logging

    REDIS_KEY = :overrides
    REDIS_CLAIMS_KEY = :override_claims

    def initialize(redis, matrix)
      @redis = redis
      @matrix = matrix
    end

    def add(*args)
      queues, processes = *args
      info("adding #{processes} overrides for #{queues.join(', ')}")
      validate!(processes)
      processes.times do
        redis.rpush(REDIS_KEY, queues.join(","))
      end
      matrix.clear!
    end

    def all
      [].tap do |result|
        raw_list.each_with_index do |queues, index|
          host = redis.lindex(REDIS_CLAIMS_KEY, index)
          result << Override.new(queues.split(",").map(&:to_sym), host)
        end
      end
    end

    def remove(*args)
      queues, processes = *args
      info("removing #{processes} overrides for #{queues.join(', ')}")
      redis.lrem(REDIS_KEY, processes, queues.join(","))
      matrix.clear!
    end

    def clear!
      clear_claims!
      info("clearing overrides")
      redis.del REDIS_KEY
    end

    def clear_claims!
      matrix.clear!
      debug("clearing overrides claimed")
      redis.del(REDIS_CLAIMS_KEY)
    end

    def overrides_for(*args)
      hostname, workers = *args
      needed = unclaimed[0..workers-1].size
      needed.times {redis.rpush(REDIS_CLAIMS_KEY, hostname)}
      claimed_by(hostname).map{|override| override.queues}
    end

    private

    attr_reader :redis, :matrix

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
      redis.lrange(REDIS_KEY, 0, -1) 
    end
  end
end
