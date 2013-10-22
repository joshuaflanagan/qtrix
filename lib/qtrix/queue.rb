require 'bigdecimal'
require 'set'

module Qtrix
  class Queue
    include Qtrix::Namespacing
    extend Qtrix::Logging
    REDIS_KEY = :queue_weights

    class << self
      def map_queue_weights(*args)
        namespace, map = extract_args(1, *args)
        map.each {|queue, weight| validate(queue.to_s, weight.to_f)}
        self.clear!(namespace)
        info("changing queue weights for #{namespace}: #{map}")
        map.each {|queue, weight| redis(namespace).zadd(REDIS_KEY, weight.to_f, queue.to_s)}
        Qtrix::Matrix.clear!(namespace)
      end


      def all_queues(namespace=:current)
        raw = redis(namespace).zrevrange(REDIS_KEY, 0, -1, withscores: true)
        result = raw.each_with_object([]) do |tuple, result|
          result << self.new(namespace, tuple[0], tuple[1].to_f)
        end
        if result.empty?
          msg = "No queue distribution defined"
          warn(msg)
          raise Qtrix::ConfigurationError, msg
        end
        result
      end

      def to_map(namespace=:current)
        all_queues(namespace).each_with_object({}) {|queue, map|
          map[queue.name] = queue.weight
        }
      end
      alias_method :to_h, :to_map

      def count(namespace=:current)
        redis(namespace).zcard(REDIS_KEY)
      end

      def total_weight(ns=:current)
        all_queues(ns).inject(0) {|memo, queue| memo += queue.weight}
      end

      def clear!(namespace=:current)
        info("clearing queue weights for #{namespace}")
        redis(namespace).del REDIS_KEY
        Qtrix::Matrix.clear! namespace
      end

      private
      def validate(name, weight)
        raise "nil name" if name.nil?
        raise "empty name" if name.empty?
        raise "nil weight" if weight.nil?
        raise "weight of 0 or less" if weight <= 0
        raise "weight cannot be > 999" if weight > 999
      end

      def high_low
        lambda{|i,j| j.weight <=> i.weight}
      end
    end
    attr_reader :name, :namespace

    def initialize(ns, name, weight)
      @namespace = ns
      @name = name.to_sym
      @weight = weight.to_f
    end

    def ==(other)
      name == other.name && weight == other.weight
    end

    def hash
      name.hash - weight.hash
    end

    def resource_percentage
      @resource_percentage ||= weight.to_f / self.class.total_weight(namespace)
    end

    def weight
      @weight ||= redis(namespace).zscore(REDIS_KEY, name).to_f
    end
  end
end
