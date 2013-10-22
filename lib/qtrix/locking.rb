##
# Provides a mechanism of distributed locking according to
# the algorithm outlined here: http://redis.io/commands/setnx
module Qtrix
  module Locking
    include Qtrix::Logging
    LOCK = :lock
    DEFAULT_WAIT_TIMEOUT = 10
    DEFAULT_MAX_DURATION = 5

    ##
    # Attempts to obtain a global qtrix lock and if its obtained,
    # execute the passed block of code.  If the lock is held by
    # another, this will block while retrying to obtain the lock.
    # If it fails to gain the lock after :wait_timeout seconds,
    # it will return the value returned by the :on_timeout callback,
    # or raise a Qtrix::LockingTimeout if no callback provided.
    # If the lock is obtained, it will set its expiration to
    # :max_duration seconds from now.
    #
    # By default this uses a 10 second wait timeout and 5 second max duration.
    def with_lock(opts={}, &block)
      result = nil
      start_time = Time.now.to_i
      wait_timeout = opts[:wait_timeout] || DEFAULT_WAIT_TIMEOUT
      max_duration = opts[:max_duration] || DEFAULT_MAX_DURATION
      on_timeout = opts[:on_timeout] || lambda{ raise Timeout }
      while(true) do
        if aquire_lock(max_duration)
          result = invoke_then_release_lock(&block)
          break
        elsif we_have_timed_out?(start_time, wait_timeout)
          debug("failed to aquire lock in #{wait_timeout}")
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
      Persistence.redis.del(LOCK)
      debug("Lock released")
    end

    def we_have_timed_out?(start_time, timeout)
      time_delta = Time.now.to_i - start_time
      (timeout > 0) && (time_delta > timeout)
    end

    def aquire_lock(max_duration)
      result = false
      expiration = expire_time(max_duration)
      if Persistence.redis.setnx(LOCK, expiration)
        debug("Lock aquired")
        result = true
      elsif now_has_surpassed(Persistence.redis.get(LOCK))
        if now_has_surpassed(Persistence.redis.getset(LOCK, expiration))
          debug("Lock aquired")
          result = true
        else
          result = false
        end
      end
      result
    end

    def now_has_surpassed(time)
      time.to_i < Persistence.redis_time
    end

    def raise_timeout
      raise "Failed to gain lock"
    end

    def expire_time(offset)
      Persistence.redis_time + offset + 1
    end

    class Timeout < StandardError
      def initialize(msg = "Failed to gain lock")
        super
      end
    end
  end
end
