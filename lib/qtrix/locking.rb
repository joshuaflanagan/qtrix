##
# Provides a mechanism of distributed locking according to
# the algorithm outlined here: http://redis.io/commands/setnx
module Qtrix
  module Locking
    include Qtrix::Namespacing
    LOCK = :lock
    DEFAULT_TIMEOUT = 10

    ##
    # Attempts to obtain a global qtrix lock and if its obtained,
    # execute the passed block of code.  If the lock is held by
    # another, this will either block for a time (specified with
    # the timeout option) to gain the lock and then fail with a
    # timeout exception, or it will immediately return a result
    # passed from the caller (via the on_timeout callable option).
    #
    # By default this uses a 10 second timeout.
    def with_lock(opts={}, &block)
      result = nil
      start_time = Time.now.to_i
      timeout_duration = opts[:timeout] || DEFAULT_TIMEOUT
      on_timeout = opts[:on_timeout] || lambda{ raise Timeout }
      while(true) do
        if aquire_lock
          result = invoke_then_release_lock(&block)
          break
        elsif we_have_timed_out(start_time, timeout_duration)
          result = on_timeout.call
          break
        end
        sleep(0.1)
      end
      result
    end

    private
    def invoke_then_release_lock(&block)
      block.call
    ensure
      release_lock
    end

    def release_lock
      # TODO only do this if we still hold the lock.
      redis.del(LOCK)
    end

    def we_have_timed_out(start_time, timeout)
      time_delta = Time.now.to_i - start_time
      (timeout > 0) && (time_delta > timeout)
    end

    def aquire_lock
      result = false
      if redis.setnx(LOCK, lock_value)
        result = true
      elsif now_has_surpassed(redis.get(LOCK))
        if now_has_surpassed(redis.getset(LOCK, lock_value))
          result = true
        else
          result = false
        end
      end
      result
    end

    def now_has_surpassed(time)
      time.to_i < redis_time
    end

    def raise_timeout
      raise "Failed to gain lock"
    end

    def lock_value
      redis_time + 5 + 1
    end

    class Timeout < StandardError
      def initialize(msg = "Failed to gain lock")
        super
      end
    end
  end
end
