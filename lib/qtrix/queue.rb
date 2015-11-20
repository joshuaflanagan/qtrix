require 'bigdecimal'
require 'set'

module Qtrix
  class Queue
    extend Qtrix::Logging
    REDIS_KEY = :queue_weights

    class << self
      def map_queue_weights(map)
        map.each {|queue, weight| validate(queue.to_s, weight.to_f)}
        self.clear!
        info("changing queue weights: #{map}")
        map.each {|queue, weight| Persistence.redis.zadd(REDIS_KEY, weight.to_f, queue.to_s)}
        Qtrix::Matrix.clear!
      end


      def all_queues
        raw = Persistence.redis.zrevrange(REDIS_KEY, 0, -1, withscores: true)
        result = raw.each_with_object([]) do |tuple, result|
          result << self.new(tuple[0], tuple[1].to_f)
        end
        if result.empty?
          msg = "No queue distribution defined"
          warn(msg)
          raise Qtrix::ConfigurationError, msg
        end
        result
      end

      def to_map
        all_queues.each_with_object({}) {|queue, map|
          map[queue.name] = queue.weight
        }
      end
      alias_method :to_h, :to_map

      def count
        Persistence.redis.zcard(REDIS_KEY)
      end

      def total_weight
        all_queues.inject(0) {|memo, queue| memo += queue.weight}
      end

      def clear!
        info("clearing queue weights")
        Persistence.redis.del REDIS_KEY
        Qtrix::Matrix.clear!
      end

      private
      def validate(name, weight)
        raise "nil name" if name.nil?
        raise "empty name" if name.empty?
        raise "nil weight" if weight.nil?
        raise "weight of 0 or less" if weight <= 0
        raise "weight cannot be > 999" if weight > 999
      end
    end
    attr_reader :name

    def initialize(name, weight)
      @name = name.to_sym
      @weight = weight.to_f
    end

    def ==(other)
      name == other.name && weight == other.weight
    end

    def hash
      name.hash - weight.hash
    end

    def relative_weight
      @relative_weight ||= weight.to_f / self.class.total_weight
    end

    def weight
      @weight ||= Persistence.redis.zscore(REDIS_KEY, name).to_f
    end
  end
end
