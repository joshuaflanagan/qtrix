require 'singleton'
require 'redis'
require 'redis-namespace'

module Qtrix
  class Persistence
    include Singleton

    # 'default' is included to keep backwards compatibility with old namespaced approach
    NAMESPACE = "qtrix:default".freeze

    attr_reader :connection_config

    def connection_config(opts={})
      @connection_config ||= opts
    end


    def self.redis
      instance.redis
    end

    def self.redis_time
      instance.redis_time
    end

    def self.connection_config(opts={})
      instance.connection_config(opts)
    end

    def redis
      @redis ||= Redis::Namespace.new(NAMESPACE, redis: client)
    end

    def client
      @client ||= Redis.connect(connection_config)
    end

    def redis_time
      # Could use redis time command, but > 2.6 only.
      redis.info.fetch("uptime_in_seconds").to_i
    end
  end
end
