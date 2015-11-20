require 'spec_helper'

describe Qtrix::OverrideStore do
  let(:queues) {[:a, :b, :c]}
  let(:matrix_store) {Qtrix::Matrix.new(redis)}
  let(:default_overrides) {raw_redis.llen("qtrix:default:overrides")}
  let(:override_claims_key) {Qtrix::OverrideStore::REDIS_CLAIMS_KEY}
  subject(:override_store) { Qtrix::OverrideStore.new(redis, matrix_store) }

  describe "#add" do
    it "should persist the override" do
      override_store.add(queues, 1)
      default_overrides.should == 1
    end

    it "should persist multiple processes as multiple rows" do
      override_store.add(queues, 1)
      override_store.add(queues, 1)
      default_overrides.should == 2
    end

    it "should raise errors if the processes are zero" do
      expect{override_store.add(queues, 0)}.to raise_error
    end

    it "should blow away the matrix" do
      override_store.add(queues, 1)
      matrix_store.to_table.should be_empty
    end
  end

  describe "#remove" do
    it "should remove the override" do
      override_store.add(queues, 1)
      override_store.remove(queues, 1)
      default_overrides.should == 0
    end

    it "should blow away the matrix" do
      override_store.remove(queues, 100)
      matrix_store.to_table.should be_empty
    end
  end

  describe "#clear_claims!" do
    before do
      override_store.add(queues, 1)
      override_store.overrides_for('localhost', 1)
    end

    it "should drop override claims from redis" do
      override_store.clear_claims! 
      redis.exists(Qtrix::OverrideStore::REDIS_CLAIMS_KEY).should_not == true
    end

    it "should not drop the overrides from redis" do
      override_store.clear_claims! 
      redis.exists(Qtrix::OverrideStore::REDIS_KEY).should == true
    end

    it "should blow away the matrix" do
      override_store.clear_claims!
      matrix_store.to_table.should be_empty
    end
  end

  describe "#clear!" do
    before do
      override_store.add(queues, 1)
      override_store.overrides_for('localhost', 1)
    end

    it "should drop override data from redis" do
      override_store.clear!
      redis.exists(Qtrix::OverrideStore::REDIS_KEY).should_not == true
    end

    it "should drop override claim data from redis" do
      override_store.clear!
      redis.exists(Qtrix::OverrideStore::REDIS_CLAIMS_KEY).should_not == true
    end

    it "should blow away the matrix" do
      override_store.clear!
      matrix_store.to_table.should be_empty
    end
  end

  describe "#overrides_for" do
    it "should return an empty list if no overrides are present" do
      override_store.overrides_for("host1", 1).should == []
    end

    it "should not generate override_claims as an artifact when no overrides are present" do
      override_store.overrides_for("host1", 1)
      raw_redis.keys("*#{override_claims_key}").should be_empty
    end

    it "should return a list of queues from an unclaimed override" do
      override_store.add(queues, 5)
      override_store.overrides_for("host1", 1).should == [queues]
    end

    it "should only generate as many override claims as exist overrides" do
      override_store.add(queues, 1)
      override_store.overrides_for("host1", 5)
      redis.llen(override_claims_key).should == 1
    end

    it "should associate the host with the override" do
      override_store.add(queues, 1)
      override_store.overrides_for("host1", 1)
      result = override_store.all.detect{|override| override.host == "host1"}
      result.should_not be_nil
    end

    it "should return existing claims on subsequent invocations" do
      override_store.add(queues, 1)
      expected = override_store.overrides_for("host1", 1)
      result = override_store.overrides_for("host1", 1)
      result.should == expected
    end

    it "should not return overrides beyond the current count of overrides" do
      override_store.add(queues, 1)
      override_store.overrides_for("host1", 3).should == [queues]
    end

    it "should not return overrides beyond the requested number of overrides" do
      override_store.add(queues, 5)
      override_store.overrides_for("host1", 1).should == [queues]
    end
  end
end
