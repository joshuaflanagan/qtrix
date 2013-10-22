require 'logger'

module Qtrix
  ##
  # Provides logging support for qtrix.
  module Logging
    def logger
      @qtrix_logger ||= Logger.new(log_path).tap do |l|
        l.level = log_level
      end
    end

    %w{debug info warn error}.each do |level|
      define_method(level) do |msg|
        logger.send(level, msg)
      end
    end

    private
    def log_path
      ENV["QTRIX_LOG"] || "log/qtrix.log"
    end

    def log_level
      if ENV["QTRIX_LOG_LEVEL"]
        Logger.const_get(ENV["QTRIX_LOG_LEVEL"].upcase.to_sym)
      else
        Logger::INFO
      end
    end
  end
end
