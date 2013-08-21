require 'qtrix/cli/spec_helper'

describe Qtrix::CLI::Overrides do
  include_context "cli commands"
  let(:overrides) {
    Qtrix::CLI::Overrides.new(stdout_stream, stderr_stream)
  }

  describe "listing override" do
    before(:each) {overrides.parse_options(["-l"])}

    it "should list all overrides" do
      Qtrix.add_override [:A], 1
      Qtrix.add_override [:B], 1
      overrides.exec
      stdout.should match /A/
      stdout.should match /B/
    end
  end

  describe "adding overrides" do
    it "should add a single override" do
      overrides.parse_options(%w{-a -q A -w 1})
      overrides.exec
      stdout.should match /A/
      Qtrix.overrides.size.should == 1
    end

    it "should add multiple overrides for multiple workers" do
      overrides.parse_options(%w{-a -q A -w 2})
      overrides.exec
      stdout.should match /A.+A/
      Qtrix.overrides.size.should == 2
    end

    it "should default to 1 worker" do
      overrides.parse_options(%w{-a -q A})
      overrides.exec
      stdout.should match /A/
      Qtrix.overrides.size.should == 1
    end

    it "should error if we dont specify any queues" do
      overrides.parse_options(%w{-a -w 2})
      overrides.exec
      stderr.should match /failure/i
      Qtrix.overrides.size.should == 0
    end
  end

  describe "deleting overrides" do
    before(:each) {Qtrix.add_override(['A'], 2)}

    it "should allow deletion of a single override" do
      overrides.parse_options(%w{-d -q A})
      overrides.exec
      stdout.should match /A/
      Qtrix.overrides.size.should == 1
    end

    it "should allow deletion of multiple overrides" do
      overrides.parse_options(%w{-d -q A -w 2})
      overrides.exec
      stdout.should match /A/
      Qtrix.overrides.size.should == 0
    end

    it "should error if we dont specify any queues" do
      overrides.parse_options(%w{-d -w 2})
      overrides.exec
      stderr.should match /failure/i
      Qtrix.overrides.size.should == 2
    end
  end

  describe "targetting to config sets" do
    before(:each) do
      Qtrix.create_configuration_set "night"
    end

    it "should be able to create overrides in the config set" do
      overrides.parse_options(%w{-c night -a -q A})
      overrides.exec
      Qtrix.overrides('night').size.should == 1
    end

    it "should be able to list overrides in the config set" do
      Qtrix.add_override('night', ['A'], 1)
      overrides.parse_options(%w{-c night -l})
      overrides.exec
      stdout.should match /A/
    end

    it "should be able to delete overrides from the config set" do
      Qtrix.add_override('night', ['A'], 1)
      overrides.parse_options(%w{-c night -d -q A})
      overrides.exec
      Qtrix.overrides('night').size.should == 0
    end
  end
end
