require 'spec_helper'

describe Qtrix::HostManager do
  include Qtrix::Namespacing
  let(:redis_key) {Qtrix::HostManager::REDIS_KEY}

  describe "#ping" do
    it "should store the ping in a sorted set in redis" do
      Qtrix::HostManager.ping("localhost")
      redis.zcard(redis_key).should == 1
    end

    it "should store only one value per host" do
      Qtrix::HostManager.ping("localhost")
      Qtrix::HostManager.ping("localhost")
      redis.zcard(redis_key).should == 1
      Qtrix::HostManager.ping("blah")
      Qtrix::HostManager.ping("blah")
      redis.zcard(redis_key).should == 2
    end
  end

  describe "#clear!" do
    it "should clear any previously stored pings" do
      Qtrix::HostManager.ping("localhost")
      redis.zcard(redis_key).should == 1
      Qtrix::HostManager.clear!
      redis.zcard(redis_key).should == 0
    end
  end

  context "no hosts have checked in" do
    describe "#all" do
      it "should return empty array" do
        Qtrix::HostManager.all.should == []
      end
    end

    describe "#offline" do
      it "should return empty array" do
        Qtrix::HostManager.offline.should == []
      end
    end

    describe "#any_offline?" do
      it "should return false" do
        Qtrix::HostManager.any_offline?.should be_false
      end
    end
  end

  context "host has checked in recently" do
    before {Qtrix::HostManager.ping("localhost")}

    describe "#all" do
      it "should return array of hosts that have checked in" do
        Qtrix::HostManager.all.should == ['localhost']
      end
    end

    describe "#offline" do
      it "should return empty array" do
        Qtrix::HostManager.offline.should == []
      end
    end

    describe "#any_offline?" do
      it "should return false" do
        Qtrix::HostManager.any_offline?.should be_false
      end
    end
  end

  context "host has not checked in recently" do
    before do
      Qtrix::HostManager.ping("localhost")
      server_time = Qtrix::HostManager.server_time
      Qtrix::HostManager.stub(:server_time) {server_time + 121}
    end

    describe "#all" do
      it "should return array of all hosts that have checked in" do
        Qtrix::HostManager.all.should == ["localhost"]
      end
    end

    describe "#offline" do
      it "should return array containing tardy hosts" do
        Qtrix::HostManager.offline.should == ["localhost"]
      end
    end

    describe "#has_hosts_oflfine?" do
      it "should return true" do
        Qtrix::HostManager.any_offline?.should be_true
      end
    end
  end
end
