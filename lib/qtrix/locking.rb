require 'redis-lock'

module Qtrix
  ##
  # Provides locking behavior so that various qtrix operations are
  # guarded by a distributed lock maintained in redis.
  module Locking
    ##
    # Indicates that a lock was not aquired within an appropriate
    # amount of time.
    class LockNotAcquired < StandardError; end

    include Namespacing
    REDIS_KEY = "qtrix:lock"

    ##
    # Executes the passed block if a lock can be obtained, or
    # returns the specified result_on_error.
    def with_lock(result_on_error=nil, &block)
      result = nil
      redis.lock(REDIS_KEY, acquire: 0.3, life: 5) do
        result = block.call
      end
      result
    rescue Redis::Lock::LockNotAcquired
      return result_on_error if result_on_error
      raise LockNotAcquired, "contention on #{REDIS_KEY}"
    end
  end
end
