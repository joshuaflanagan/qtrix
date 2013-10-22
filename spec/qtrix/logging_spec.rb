require 'fileutils'
require 'spec_helper'

describe Qtrix::Logging do
  let(:object) {Object.new.extend Qtrix::Logging}
  let(:log_path) {'log/qtrix.log'}
  let(:other_log_path) {'log/qtrix_other.log'}

  before do
    @old_logger = ENV.delete("QTRIX_LOG")
    @old_log_level = ENV.delete("QTRIX_LOG_LEVEL")
  end

  after do
    FileUtils.rm_f(log_path)
    FileUtils.rm_f(other_log_path)
    ENV["QTRIX_LOG"] = @old_logger
    ENV["QTRIX_LOG_LEVEL"] = @old_log_level
  end

  describe "#logger" do
    it "should provide access to a Logger object" do
      object.logger.should be_a(Logger)
    end

    it "should write to log/qtrix.log by default" do
      object.logger.info("Howdy")
      File.read(log_path).should =~ /Howdy/
    end

    it "should have a default log level of info" do
      object.logger.level.should == Logger::INFO
    end

    it "should allow QTRIX_LOG to specify log location" do
      ENV["QTRIX_LOG"] = other_log_path
      object.logger.info("Howdy Mate")
      File.read(other_log_path).should =~ /Howdy Mate/
    end

    it "should allow QTRIX_LOG_LEVEL to specify log level" do
      ENV["QTRIX_LOG_LEVEL"] = "debug"
      object.logger.level.should == Logger::DEBUG
    end

    it "should only instantiate one logger ever" do
      object.logger.should == object.logger
    end
  end

  describe "#debug" do
    it "should route log message to logger" do
      object.info("debug")
      File.read(log_path).should =~ /debug/
    end
  end

  describe "#info" do
    it "should route log message to logger" do
      object.info("info")
      File.read(log_path).should =~ /info/
    end
  end

  describe "#warn" do
    it "should route log message to logger" do
      object.warn("warn")
      File.read(log_path).should =~ /warn/
    end
  end

  describe "#error" do
    it "should route log message to logger" do
      object.error("error")
      File.read(log_path).should =~ /error/
    end
  end
end
