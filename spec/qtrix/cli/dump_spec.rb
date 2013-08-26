require 'fileutils'
require 'tmpdir'
require 'qtrix/cli/spec_helper'

describe Qtrix::CLI::Dump do
  include_context "cli commands"

  let(:command) {Qtrix::CLI::Dump.new(stdout_stream, stderr_stream)}
  let(:dump) {File.readlines("qtrix.dump")}

  context "to specified file path" do
    it "should write file to specified path" do
      path = File.join(Dir.mktmpdir, 'test.dump')
      command.parse_options "-f #{path}".split
      command.exec
      File.exists?(path).should == true
    end
  end

  context "to default file path with default and night config sets" do
    before(:each) do
      Qtrix.map_queue_weights A: 10, B: 8
      Qtrix.add_override [:Y,:Z], 2
      Qtrix.create_configuration_set(:night)
      Qtrix.map_queue_weights :night, C: 10, D: 5
      Qtrix.add_override :night, [:I,:J], 2
      command.parse_options
      command.exec
    end

    after(:each) {FileUtils.rm('qtrix.dump')}

    it "should create dump file containing command to create night config set" do
      pattern = /bundle exec qtrix config_sets --create night -h localhost -p 6379 -n 0/
      dump.grep(pattern).should_not be_empty
    end

    it "should create dump file that does not contain command to create default config set" do
      pattern = /--create default/
      dump.grep(pattern).should be_empty
    end

    it "should create dump file that contains command to map defaults queue weights" do
      pattern = /bundle exec qtrix queues -w A:10.0,B:8.0 -c default -h localhost -p 6379 -n 0/
      dump.grep(pattern).should_not be_empty
    end

    it "should create dump file that contains command to map night's queue weights" do
      pattern = /bundle exec qtrix queues -w C:10.0,D:5.0 -c night -h localhost -p 6379 -n 0/
      dump.grep(pattern).should_not be_empty
    end

    it "should create dump file that contains commands to add default's overrides" do
      pattern = /bundle exec qtrix overrides -a -q Y,Z -w 1 -c default -h localhost -p 6379 -n 0/
      dump.grep(pattern).size.should == 2
    end

    it "should create dump file that contains commands to add default's overrides" do
      pattern = /bundle exec qtrix overrides -a -q I,J -w 1 -c night -h localhost -p 6379 -n 0/
      dump.grep(pattern).size.should == 2
    end

    it "should create dump file that is executable" do
      File.executable?("qtrix.dump").should == true
    end
  end
end
