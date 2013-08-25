require 'qtrix/cli/spec_helper'

describe Qtrix::CLI::ConfigSets do
  include_context "cli commands"
  let(:config_sets) {
    Qtrix::CLI::ConfigSets.new(stdout_stream, stderr_stream)
  }

  describe "listing configuration sets" do
    before(:each) {config_sets.parse_options(["-l"])}

    it "should display default when no config sets have been added" do
      config_sets.exec
      stdout.should match /default/
    end

    it "should display all config sets" do
      Qtrix.create_configuration_set :night
      config_sets.exec
      stdout.should match /default/
      stdout.should match /night/
    end
  end

  describe "current configuration set" do
    before(:each) {config_sets.parse_options(["-c"])}

    it "should display the current configuration set" do
      Qtrix.create_configuration_set :night
      Qtrix.map_queue_weights :night, A: 10
      Qtrix.activate_configuration_set! :night
      config_sets.exec
      stdout.should match /night/
    end
  end

  describe "create configuration set" do
    it "should allow creation of a new configuration set" do
      config_sets.parse_options "--create day".split
      config_sets.exec
      stdout.should match /success/
      Qtrix.configuration_sets.include?(:day).should == true
    end

    it "should not allow creation of duplicate configuration sets" do
      Qtrix.create_configuration_set 'night'
      config_sets.parse_options "--create night".split
      config_sets.exec
      stderr.should match /failure/i
      Qtrix.configuration_sets.select{|cs| cs == :default}.size.should == 1
    end
  end

  describe "activate configuration set" do
    it "should change the current confguration set to the one specified" do
      Qtrix.create_configuration_set 'night'
      Qtrix.map_queue_weights 'night', A: 10
      config_sets.parse_options "-a night".split
      config_sets.exec
      stdout.should match /success/i
      Qtrix.current_configuration_set.should == :night
    end
  end

  describe "remove configuration set" do
    before(:each) do
      Qtrix.create_configuration_set :night
      Qtrix.map_queue_weights :night, A: 10
    end

    it "should delete all data for the given configuration set" do
      config_sets.parse_options "-d night".split
      config_sets.exec
      stdout.should match /success/
      Qtrix.configuration_sets.detect{|cs| cs == :night}.should be_nil
    end

    it "should not allow removal of the current configuration set" do
      Qtrix.activate_configuration_set! :night
      config_sets.parse_options "-d night".split
      config_sets.exec
      stderr.should match /failure/i
      Qtrix.configuration_sets.select{|cs| cs == :night}.size.should == 1
    end

    it "should not allow removal of the default configuration set" do
      Qtrix.activate_configuration_set! :night
      config_sets.parse_options "-d default".split
      config_sets.exec
      stderr.should match /failure/i
      Qtrix.configuration_sets.select{|cs| cs == :default}.size.should == 1
    end
  end
end
