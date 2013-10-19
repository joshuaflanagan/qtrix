##
# Provides a mechanism of distributed locking according to
# the algorithm outlined here: http://redis.io/commands/setnx
module Qtrix
  module Locking
    include Qtrix::Namespacing
    LOCK = :lock

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
      opts[:start_time] = Time.now
      while(true) do
        if aquire_lock
          result = invoke_then_release_lock(&block)
          break
        elsif we_have_timed_out(opts)
          if opts[:on_timeout]
            result = opts[:on_timeout].call
            break
          else
            raise_timeout
          end
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

    def we_have_timed_out(opts)
      time_delta = Time.now.to_i - opts[:start_time].to_i
      opts[:timeout] && time_delta > timeout_length(opts)
    end

    def timeout_length(opts)
      opts[:timeout].to_i || 10
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
  end
end
