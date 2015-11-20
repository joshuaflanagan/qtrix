require 'spec_helper'

class DummyJob
  @queue = :test_queue
end

describe Qtrix::Queue do
  before(:each) do
    Qtrix::Queue.map_queue_weights a: 2, b: 3
  end
  let(:all_queues) {Qtrix::Queue.all_queues}
  let(:queue1) {all_queues[1]}
  let(:queue2) {all_queues[0]}
  let(:matrix) {Qtrix::Matrix}

  context "comparing two queues with the same name and weights" do
    let(:other_queue) {Qtrix::Queue.new(:a, 2)}
    describe "#==" do
      it "should return true" do
        queue1.should == other_queue
      end
    end

    describe "#hash" do
      it "should return the same result" do
        queue1.hash.should == other_queue.hash
      end
    end
  end

  context "comparing two queues with the same name and different weights" do
    let(:other_queue) {other_queue = Qtrix::Queue.new(:a, 3)}
    describe "#==" do
      it "should return false" do
        queue1.should_not == other_queue
      end
    end

    describe "#hash" do
      it "should return different results" do
        queue1.hash.should_not == other_queue.hash
      end
    end
  end

  context "comparing two queues with the same weight and different names" do
    let(:other_queue) {other_queue = Qtrix::Queue.new(:b, 2)}
    describe "#==" do
      it "should return false" do
        queue1.should_not == other_queue
      end
    end

    describe "#hash" do
      it "should return different results" do
        queue1.hash.should_not == other_queue.hash
      end
    end
  end

  describe "#resource_percentage" do
    it "should equal weight / total weight of all queues" do
      queue1.resource_percentage.should == 0.4
      queue2.resource_percentage.should == 0.6
    end
  end

  context "class instance methods" do
    include_context "established qtrix configuration"
    describe "#map_queue_weights" do
      it "should remove old queues" do
        Qtrix::Queue.map_queue_weights A: 100
        result = Qtrix::Queue.all_queues.map(&:name)
        result.include?(:B).should_not be_true
        result.include?(:C).should_not be_true
      end

      it "should add new queues ordered according to weight" do
        results = Qtrix::Queue.all_queues
        results.map(&:name).should == [:A, :B, :C]
        results.map(&:weight).should == [3, 2, 1]
      end

      it "should error when trying to save empty queue name" do
        expect{Qtrix::Queue.map_queue_weights('' => 1)}.to raise_error
      end

      it "should error when trying to save nil weight" do
        expect{Qtrix::Queue.map_queue_weights(c: nil)}.to raise_error
      end

      it "should error when trying to save weight of 0" do
        expect{Qtrix::Queue.map_queue_weights(c: 0)}.to raise_error
      end

      it "should error when trying to save weight of > 1000" do
        expect{Qtrix::Queue.map_queue_weights(d: 1000)}.to raise_error
      end

      it "should blow away the matrix" do
        matrix.fetch_queues('host1', 1)
        matrix.to_table.should_not be_empty
        Qtrix::Queue.map_queue_weights \
          A: 1,
          B: 2
        matrix.to_table.should be_empty
      end
    end

    describe "#all_queues" do
      describe "with no distributions defined" do
        it "should raise a configuration error" do
          Qtrix::Queue.clear!
          expect {
            Qtrix::Queue.all_queues
          }.to raise_error Qtrix::ConfigurationError
        end
      end
      it "should contain all queues sorted by weight desc" do
        Qtrix::Queue.all_queues.map(&:name).should == [:A, :B, :C]
      end
    end

    describe "#to_map" do
      it "should return a map containing all queue names mapped to their weights" do
        map = {A: 10, B: 4}
        Qtrix::Queue.map_queue_weights(map)
        Qtrix::Queue.to_map.should == map
      end
    end

    describe "#count" do
      it "should be the number of queues mapped" do
        Qtrix::Queue.count.should == 3
      end
    end

    describe "#total_weight" do
      it "should contain the sum of all weights" do
        Qtrix::Queue.total_weight == 6
      end
    end

    describe "#clear!" do
      before(:each) {Qtrix::Queue.clear!}
      it "should remove all existing queue weights" do
        redis.exists(Qtrix::Queue::REDIS_KEY).should_not == true
      end

      it "should blow away the matrix" do
        matrix.to_table.should be_empty
      end
    end
  end
end
