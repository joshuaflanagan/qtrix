module Qtrix
  class Client
    attr_reader :redis

    def initialize(redis)
      @redis = redis
    end
  end
end
