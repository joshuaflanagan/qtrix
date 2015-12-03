require 'bigdecimal'
require 'set'

module Qtrix
  class Queue
    REDIS_KEY = :queue_weights

    attr_reader :name, :weight, :relative_weight

    def initialize(name, weight, relative_weight)
      @name = name.to_sym
      @weight = weight.to_f
      @relative_weight = relative_weight
    end

    def ==(other)
      name == other.name && weight == other.weight
    end

    def hash
      name.hash - weight.hash
    end
  end
end
