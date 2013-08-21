require 'spec_helper'

describe Orchestrator::Override do
  include Orchestrator::Namespacing
  include_context "established default and night namespaces"

  let(:queues) {[:a, :b, :c]}
  let(:matrix) {Orchestrator::Matrix}
  let(:default_overrides) {raw_redis.llen("orchestrator:default:overrides")}
  let(:night_overrides) {raw_redis.llen("orchestrator:night:overrides")}

  before do
    raw_redis.del "orchestrator:default:overrides"
    raw_redis.del "orchestrator:night:overrides"
  end

  def override_count(ns=:current)
    override = Orchestrator::Override.all(ns).detect{|o| o.queues == queues}
    override ? override.processes : 0
  end

  describe "#add" do
    describe "with no namespace passed" do
      it "should persist the override in the current ns" do
        Orchestrator::Override.add(queues, 1)
        default_overrides.should == 1
      end

      it "should persist multiple processes as multiple rows" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.add(queues, 1)
        default_overrides.should == 2
      end

      it "should raise errors if the processes are zero" do
        expect{Orchestrator::Override.add(queues, 0)}.to raise_error
      end

      it "should blow away the matrix in the current ns" do
        Orchestrator::Override.add(queues, 1)
        matrix.to_table.should be_empty
      end
    end

    describe "with namespace passed" do
      it "should persist the override in the target ns" do
        Orchestrator::Override.add(:night, queues, 1)
        night_overrides.should == 1
        default_overrides.should == 0
      end
    end
  end

  describe "#remove" do
    describe "with no namespace passed" do
      it "should remove the override in the current ns" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.remove(queues, 1)
        default_overrides.should == 0
      end

      it "should blow away the matrix in the current ns" do
        Orchestrator::Override.remove(queues, 100)
        matrix.to_table.should be_empty
      end
    end

    describe "with namespace passed" do
      it "should remove the override in the target ns" do
        Orchestrator::Override.add(:night, queues, 2)
        Orchestrator::Override.remove(:night, queues, 1)
        night_overrides.should == 1
        default_overrides.should == 0
      end

      it "should blow away the matrix in the target ns" do
        Orchestrator::Override.remove(:night, queues, 100)
        matrix.to_table(:night).should be_empty
      end
    end
  end

  describe "#clear!" do
    describe "with no namespace passed" do
      it "should drop all override data from redis" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.clear!
        redis.exists(Orchestrator::Override::REDIS_KEY).should_not == true
      end

      it "should blow away the matrix" do
        Orchestrator::Override.clear!
        matrix.to_table.should be_empty
      end
    end

    describe "with namespace passed" do
      it "should drop override data from the target namespace" do
        Orchestrator::Override.add(:night, queues, 1)
        Orchestrator::Override.clear! :night
        raw_redis.llen("orchestrator:night:overrides").should == 0
      end

      it "should blow away the matrix in target namespace" do
        Orchestrator::Override.clear!(:night)
        matrix.to_table(:night).should be_empty
      end
    end
  end

  describe "#overrides_for" do
    describe "with no namespace passed" do
      it "should return an empty list if no overrides are present" do
        Orchestrator::Override.overrides_for("host1", 1).should == []
      end

      it "should return a list of queues from an unclaimed override" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.overrides_for("host1", 1).should == [queues]
      end

      it "should associate the host with the override" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.overrides_for("host1", 1)
        result = Orchestrator::Override.all.detect{|override| override.host == "host1"}
        result.should_not be_nil
      end

      it "should return existing claims on subsequent invocations" do
        Orchestrator::Override.add(queues, 1)
        expected = Orchestrator::Override.overrides_for("host1", 1)
        result = Orchestrator::Override.overrides_for("host1", 1)
        result.should == expected
      end

      it "should not return overrides beyond the current count of overrides" do
        Orchestrator::Override.add(queues, 1)
        Orchestrator::Override.overrides_for("host1", 3).should == [queues]
      end

      it "should not return overrides beyond the requested number of overrides" do
        Orchestrator::Override.add(queues, 5)
        Orchestrator::Override.overrides_for("host1", 1).should == [queues]
      end
    end

    describe "with namespace passed" do
      it "should limit the operation to the passed namespace" do
        Orchestrator::Override.add(:night, queues, 1)
        Orchestrator::Override.overrides_for(:current, "host", 1).should == []
        Orchestrator::Override.overrides_for(:night, "host", 1).should == [queues]
      end
    end
  end
end
