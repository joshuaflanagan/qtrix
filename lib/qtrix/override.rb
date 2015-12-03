module Qtrix
  class Override
    attr_reader :queues, :host

    def hash
      @queues.hash ^ @processes.hash
    end

    def eql?(other)
      self.class.equal?(other.class) &&
        @host == other.host &&
        @queues == other.queues
    end
    alias == eql?

    def initialize(queues, host=nil)
      @queues = queues
      @host = host
    end
  end
end
