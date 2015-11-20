module Qtrix
  class QueueStore
    include Qtrix::Logging

    def initialize(redis)
      @redis = redis
    end

    def map_queue_weights(map)
      map.each {|queue, weight| validate_queue(queue.to_s, weight.to_f)}
      clear!
      info("changing queue weights: #{map}")
      map.each {|queue, weight| redis.zadd(Queue::REDIS_KEY, weight.to_f, queue.to_s)}
    end

    def clear!
      info("clearing queue weights")
      redis.del Queue::REDIS_KEY
      matrix_store.clear!
    end


    def all_queues
      # load queues as an array of arrays, where each inner array is a
      # name and weight: [[:queueA, 5.0],[:queueB, 3.0]]
      raw = redis.zrevrange(Queue::REDIS_KEY, 0, -1, withscores: true)
      total_weight = raw.inject(0){|sum,tuple| sum + tuple[1]}

      # build immutable Queue instances
      queues = raw.map{|name, weight|
        relative_weight = weight.to_f / total_weight
        Queue.new(name, weight, relative_weight)
      }
      if queues.empty?
        msg = "No queue distribution defined"
        warn(msg)
        raise Qtrix::ConfigurationError, msg
      end
      queues
    end

    def to_map
      all_queues.each_with_object({}) {|queue, map|
        map[queue.name] = queue.weight
      }
    end
    alias_method :to_h, :to_map

    def count
      redis.zcard(Queue::REDIS_KEY)
    end

    private

    attr_reader :redis

    def matrix_store
      @matrix_store ||= Matrix.new(redis)
    end

    def validate_queue(name, weight)
      raise "nil name" if name.nil?
      raise "empty name" if name.empty?
      raise "nil weight" if weight.nil?
      raise "weight of 0 or less" if weight <= 0
      raise "weight cannot be > 999" if weight > 999
    end
  end
end
