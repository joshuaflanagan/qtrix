require 'qtrix/cli/spec_helper'
require 'tmpdir'

describe Qtrix::CLI::Queues do
  include_context "cli commands"
  let(:queues) {
    Qtrix::CLI::Queues.new(stdout_stream, stderr_stream)
  }
  describe "queue --weights (-w)" do
    it "set the queue weights" do
      queues.parse_options(["-w", "A:40,B:30"])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution.size.should == 2
    end
  end

  describe "queue --yaml (-y)" do
    around(:each) do |example|
      yaml = YAML.dump({A: 40, B: 30, C: 20, D: 10})
      Dir.mktmpdir do |dir|
        @path = File.join(dir, "queue_weight.yml")
        File.write(@path, yaml)
        example.run
      end
    end

    it "set the queue weights from a yaml file" do
      queues.parse_options(["-y", @path])
      queues.exec
      stdout.should match /OK/
      Qtrix.desired_distribution.size.should == 4
    end
  end

  describe "queues --list (-l)" do
    it "show the desired distribution list" do
      Qtrix.map_queue_weights A: 10
      queues.parse_options(["-l"])
      queues.exec
      stdout.should match /A/
      stdout.should match /10/
    end
  end
end
