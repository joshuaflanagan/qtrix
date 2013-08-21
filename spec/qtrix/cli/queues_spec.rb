require 'qtrix/cli/spec_helper'
require 'tmpdir'

describe Qtrix::CLI::Queues do
  include_context "cli commands"
  let(:queues) {
    Qtrix::CLI::Queues.new(stdout_stream, stderr_stream)
  }
  describe "queue weights" do
    it "should set the queue weights for the current config set" do
      queues.parse_options(["-w", "A:40,B:30"])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution.size.should == 2
    end

    it "should be targettable to a configuration set" do
      Qtrix.create_configuration_set "night"
      queues.parse_options(["-w", "A:100", "-c", "night"])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution("night").size.should == 1
    end
  end

  describe "queue weights by yaml" do
    around(:each) do |example|
      yaml = YAML.dump({A: 40, B: 30, C: 20, D: 10})
      Dir.mktmpdir do |dir|
        @path = File.join(dir, "queue_weight.yml")
        File.write(@path, yaml)
        example.run
      end
    end

    it "should set the queue weights for the current config set" do
      queues.parse_options(["-y", @path])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution.size.should == 4
    end

    it "should set the queue weights for a targetted config set" do
      Qtrix.create_configuration_set "night"
      queues.parse_options(["-y", @path, "-c", "night"])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution("night").size.should == 4
    end
  end

  describe "list desired distribution" do
    it "should return the list from the current config set" do
      Qtrix.map_queue_weights A: 10
      queues.parse_options(["-l"])
      queues.exec
      stdout.should match /A/
      stdout.should match /10/
    end

    it "should return the list from a specified config set" do
      Qtrix.create_configuration_set "night"
      Qtrix.map_queue_weights B: 11
      queues.parse_options(["-l", "-c", "night"])
      queues.exec
      stdout.should match /B/
      stdout.should match /11/
    end
  end
end
