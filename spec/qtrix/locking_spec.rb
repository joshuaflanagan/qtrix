require 'spec_helper'

describe Qtrix::Locking do
  include Qtrix::Locking
  include Qtrix::Namespacing
  let(:redis_key) {Qtrix::Locking::REDIS_KEY}
  let(:namespacing_manager) {Qtrix::Namespacing::Manager.instance}

  def fork_lock_and_sleep_for(duration)
    fork do
      redis = Redis.new
      redis.select(15)
      redis.lock(redis_key) {sleep(duration)}
    end
    sleep(0.05)
  end

  describe "#locked" do
    context "when no contention exists" do
      it "should return result of block call" do
        with_lock("arg"){"block"}.should == "block"
      end
    end

    context "when normal contention exists" do
      before do
        fork_lock_and_sleep_for(0.2)
      end

      it "should return result of block call" do
        with_lock{"block"}.should == "block"
      end
    end

    context "when deadlock exists" do
      before do
        fork_lock_and_sleep_for(5)
      end

      context "and result_on_error provided" do
        it "should return result_on_error" do
          with_lock("arg"){'block'}.should == 'arg'
        end
      end

      context "and result_on_error not provided" do
        it "should raise Qtrix::Locking::LockNotAcquired" do
          expect{with_lock{'block'}}
            .to raise_error(Qtrix::Locking::LockNotAcquired)
        end
      end
    end
  end
end
