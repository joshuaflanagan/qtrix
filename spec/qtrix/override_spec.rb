require 'spec_helper'

describe Qtrix::Override do
  include_context "established qtrix configuration"

  let(:queues) {[:a, :b, :c]}
  let(:matrix) {Qtrix::Matrix}
  let(:default_overrides) {raw_redis.llen("qtrix:default:overrides")}
  let(:override_claims_key) {Qtrix::Override::REDIS_CLAIMS_KEY}

  before do
    raw_redis.del "qtrix:default:overrides"
  end

  def override_count(ns=:current)
    override = Qtrix::Override.all(ns).detect{|o| o.queues == queues}
    override ? override.processes : 0
  end

  describe "#add" do
    describe "with no namespace passed" do
      it "should persist the override in the current ns" do
        Qtrix::Override.add(queues, 1)
        default_overrides.should == 1
      end

      it "should persist multiple processes as multiple rows" do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.add(queues, 1)
        default_overrides.should == 2
      end

      it "should raise errors if the processes are zero" do
        expect{Qtrix::Override.add(queues, 0)}.to raise_error
      end

      it "should blow away the matrix in the current ns" do
        Qtrix::Override.add(queues, 1)
        matrix.to_table.should be_empty
      end
    end
  end

  describe "#remove" do
    describe "with no namespace passed" do
      it "should remove the override in the current ns" do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.remove(queues, 1)
        default_overrides.should == 0
      end

      it "should blow away the matrix in the current ns" do
        Qtrix::Override.remove(queues, 100)
        matrix.to_table.should be_empty
      end
    end
  end

  describe "#clear_claims!" do
    describe "with no namespace passed" do
      before do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.overrides_for('localhost', 1)
      end

      it "should drop override claims from redis" do
        Qtrix::Override.clear_claims! 
        redis.exists(Qtrix::Override::REDIS_CLAIMS_KEY).should_not == true
      end

      it "should not drop the overrides from redis" do
        Qtrix::Override.clear_claims! 
        redis.exists(Qtrix::Override::REDIS_KEY).should == true
      end

      it "should blow away the matrix" do
        Qtrix::Override.clear_claims!
        matrix.to_table.should be_empty
      end
    end
  end

  describe "#clear!" do
    describe "with no namespace passed" do
      before do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.overrides_for('localhost', 1)
      end

      it "should drop override data from redis" do
        Qtrix::Override.clear!
        redis.exists(Qtrix::Override::REDIS_KEY).should_not == true
      end

      it "should drop override claim data from redis" do
        Qtrix::Override.clear!
        redis.exists(Qtrix::Override::REDIS_CLAIMS_KEY).should_not == true
      end

      it "should blow away the matrix" do
        Qtrix::Override.clear!
        matrix.to_table.should be_empty
      end
    end
  end

  describe "#overrides_for" do
    describe "with no namespace passed" do
      it "should return an empty list if no overrides are present" do
        Qtrix::Override.overrides_for("host1", 1).should == []
      end

      it "should not generate override_claims as an artifact when no overrides are present" do
        Qtrix::Override.overrides_for("host1", 1)
        raw_redis.keys("*#{override_claims_key}").should be_empty
      end

      it "should return a list of queues from an unclaimed override" do
        Qtrix::Override.add(queues, 5)
        Qtrix::Override.overrides_for("host1", 1).should == [queues]
      end

      it "should only generate as many override claims as exist overrides" do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.overrides_for("host1", 5)
        redis.llen(override_claims_key).should == 1
      end

      it "should associate the host with the override" do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.overrides_for("host1", 1)
        result = Qtrix::Override.all.detect{|override| override.host == "host1"}
        result.should_not be_nil
      end

      it "should return existing claims on subsequent invocations" do
        Qtrix::Override.add(queues, 1)
        expected = Qtrix::Override.overrides_for("host1", 1)
        result = Qtrix::Override.overrides_for("host1", 1)
        result.should == expected
      end

      it "should not return overrides beyond the current count of overrides" do
        Qtrix::Override.add(queues, 1)
        Qtrix::Override.overrides_for("host1", 3).should == [queues]
      end

      it "should not return overrides beyond the requested number of overrides" do
        Qtrix::Override.add(queues, 5)
        Qtrix::Override.overrides_for("host1", 1).should == [queues]
      end
    end
  end
end
