require 'orchestrator/cli/spec_helper'

describe Orchestrator::CLI::ConfigSets do
  include_context "cli commands"
  let(:config_sets) {
    Orchestrator::CLI::ConfigSets.new(stdout_stream, stderr_stream)
  }

  describe "listing configuration sets" do
    before(:each) {config_sets.parse_options(["-l"])}

    it "should display default when no config sets have been added" do
      config_sets.exec
      stdout.should match /default/
    end

    it "should display all config sets" do
      Orchestrator.create_configuration_set :night
      config_sets.exec
      stdout.should match /default/
      stdout.should match /night/
    end
  end

  describe "current configuration set" do
    before(:each) {config_sets.parse_options(["-c"])}

    it "should display the current configuration set" do
      Orchestrator.create_configuration_set :night
      Orchestrator.map_queue_weights :night, A: 10
      Orchestrator.activate_configuration_set! :night
      config_sets.exec
      stdout.should match /night/
    end
  end

  describe "create configuration set" do
    it "should allow creation of a new configuration set" do
      config_sets.parse_options "--create day".split
      config_sets.exec
      stdout.should match /success/
      Orchestrator.configuration_sets.include?(:day).should == true
    end

    it "should not allow creation of duplicate configuration sets" do
      Orchestrator.create_configuration_set 'night'
      config_sets.parse_options "--create night".split
      config_sets.exec
      stderr.should match /failure/i
      Orchestrator.configuration_sets.select{|cs| cs == :default}.size.should == 1
    end
  end

  describe "activate configuration set" do
    it "should allow activation of a configuration set" do
      Orchestrator.create_configuration_set 'night'
      Orchestrator.map_queue_weights 'night', A: 10
      config_sets.parse_options "-a night".split
      config_sets.exec
      stdout.should match /success/i
      Orchestrator.current_configuration_set.should == :night
    end
  end

  describe "remove configuration set" do
    before(:each) do
      Orchestrator.create_configuration_set :night
      Orchestrator.map_queue_weights :night, A: 10
    end

    it "should allow removal of a configuration set" do
      config_sets.parse_options "-d night".split
      config_sets.exec
      stdout.should match /success/
      Orchestrator.configuration_sets.detect{|cs| cs == :night}.should be_nil
    end

    it "should not allow removal of the current configuration set" do
      Orchestrator.activate_configuration_set! :night
      config_sets.parse_options "-d night".split
      config_sets.exec
      stderr.should match /failure/i
      Orchestrator.configuration_sets.select{|cs| cs == :night}.size.should == 1
    end

    it "should not allow removal of the default configuration set" do
      Orchestrator.activate_configuration_set! :night
      config_sets.parse_options "-d default".split
      config_sets.exec
      stderr.should match /failure/i
      Orchestrator.configuration_sets.select{|cs| cs == :default}.size.should == 1
    end
  end
end
