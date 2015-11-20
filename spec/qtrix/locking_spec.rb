require 'spec_helper'

describe Qtrix::Locking do
  subject(:locker) { Qtrix::Locking.new(redis) }

  describe "#with_lock" do
    context "when lock is not held by other" do
      it "should invoke block" do
        result = locker.with_lock timeout: 0.1 do
          "test passed"
        end
        result.should == "test passed"
      end

      it "should release the lock when done" do
        locker.with_lock timeout: 0.1 do
          :do_nothing
        end
        redis.get(:lock).should == nil
      end

      it "should release the lock if block raises exception" do
        block_executed = false
        begin
          locker.with_lock timeout: 0.1 do
            redis.get(:lock).should_not be_nil
            block_executed = true
            raise 'uh oh'
          end
        rescue RuntimeError => e
        end
        block_executed.should == true
        redis.get(:lock).should == nil
      end
    end

    context "when lock is held by other" do
      it "should raise error if timeout exceeded" do
        redis.set :lock, Qtrix::Persistence.redis_time + 2
        expect {
          locker.with_lock timeout: 0.1 do
            "test failed"
          end
        }.to raise_error(Qtrix::Locking::Timeout)
      end

      it "should return on_timeout result if provided" do
        redis.set :lock, Qtrix::Persistence.redis_time + 2
        on_timeout = ->() {"it was locked"}
        result = locker.with_lock timeout: 0.1, on_timeout: on_timeout do
          "it was not locked"
        end
        result.should == "it was locked"
      end
    end

    context "when lock is held then released by other" do
      it "should return the block value" do
        redis.set :lock, Qtrix::Persistence.redis_time
        fork {
          sleep 0.2
          raw_redis.del "qtrix:default:lock"
        }
        result = locker.with_lock do
          "lock was eventually released"
        end
        result.should == "lock was eventually released"
      end
    end

    context "when encountering stale locks" do
      it "should execute its block" do
        redis.set :lock, Qtrix::Persistence.redis_time - 10
        result = locker.with_lock timeout: 0.2 do
          "We weren't held up by stale lock"
        end
        result.should == "We weren't held up by stale lock"
      end
    end
  end
end
