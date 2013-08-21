require 'bigdecimal'

module Orchestrator
  module Matrix
    module Common
      REDIS_KEY = :matrix
      def self.included(base)
        base.send(:extend, self)
      end

      def pack(item)
        # Marshal is fast but not human readable, might want to
        # go for json or yaml. This is fast at least.
        Marshal.dump(item)
      end

      def unpack(item)
        Marshal.restore(item)
      end
    end
  end
end
