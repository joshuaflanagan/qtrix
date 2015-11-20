module Qtrix
  class HostManager
    include Qtrix::Logging
    REDIS_KEY = :known_hosts

    def initialize(redis)
      @redis = redis
    end

    ##
    # Notifies that a host has checked in recently.
    def ping(host)
      debug("Pinging from #{host}")
      redis.zadd(REDIS_KEY, Persistence.redis_time, host)
    end

    ##
    # All hosts known to the host manager.
    def all
      redis.zrevrange(REDIS_KEY, 0, -1)
    end

    ##
    # Returns any hosts that are M.I.A and should be considered offline.
    # This is any host that has not checked in within the last 15
    # seconds.
    def offline
      host_entries = redis.zrevrange(REDIS_KEY, 0, -1, withscores: true)
      host_entries.each_with_object([]) do |(host, last_checkin), result|
        result << host if is_mia?(last_checkin)
      end
    end

    ##
    # True if any hosts have not checked in recently, or false otherwise.
    def any_offline?
      offline.size > 0
    end

    ##
    # Clears the host map.
    def clear!
      debug("Clearing known hosts")
      redis.del(REDIS_KEY)
    end

    private

    attr_reader :redis

    def is_mia?(time)
      (time.to_i + mia_time) <= Persistence.redis_time
    end

    def mia_time
      @mia_time ||= ENV.fetch('MIA_TIME', 120).to_i
    end
  end
end
