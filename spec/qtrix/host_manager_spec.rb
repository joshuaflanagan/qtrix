require 'spec_helper'

describe Qtrix::HostManager do
  let(:redis_key) {Qtrix::HostManager::REDIS_KEY}
  subject(:host_manager) { Qtrix::HostManager.new(redis) }

  describe "#ping" do
    it "should store the hostname in a sorted set in redis" do
      host_manager.ping("localhost")
      redis.zcard(redis_key).should == 1
    end

    it "should store only one value per host" do
      host_manager.ping("localhost")
      host_manager.ping("localhost")
      redis.zcard(redis_key).should == 1
      host_manager.ping("blah")
      host_manager.ping("blah")
      redis.zcard(redis_key).should == 2
    end
  end

  describe "#clear!" do
    it "should clear any previously stored hosts" do
      host_manager.ping("localhost")
      redis.zcard(redis_key).should == 1
      host_manager.clear!
      redis.zcard(redis_key).should == 0
    end
  end

  context "no hosts have checked in" do
    describe "#all" do
      it "should return empty array" do
        host_manager.all.should == []
      end
    end

    describe "#offline" do
      it "should return empty array" do
        host_manager.offline.should == []
      end
    end

    describe "#any_offline?" do
      it "should return false" do
        host_manager.any_offline?.should be_false
      end
    end
  end

  context "host has checked in recently" do
    before {host_manager.ping("localhost")}

    describe "#all" do
      it "should return array of hosts that have checked in" do
        host_manager.all.should == ['localhost']
      end
    end

    describe "#offline" do
      it "should return empty array" do
        host_manager.offline.should == []
      end
    end

    describe "#any_offline?" do
      it "should return false" do
        host_manager.any_offline?.should be_false
      end
    end
  end

  context "host has not checked in recently" do
    before do
      host_manager.ping("localhost")
      redis_time = Qtrix::Persistence.redis_time
      Qtrix::Persistence.stub(:redis_time) {redis_time + 121}
    end

    describe "#all" do
      it "should return array of all hosts that have checked in" do
        host_manager.all.should == ["localhost"]
      end
    end

    describe "#offline" do
      it "should return array containing tardy hosts" do
        host_manager.offline.should == ["localhost"]
      end
    end

    describe "#has_hosts_oflfine?" do
      it "should return true" do
        host_manager.any_offline?.should be_true
      end
    end
  end
end
