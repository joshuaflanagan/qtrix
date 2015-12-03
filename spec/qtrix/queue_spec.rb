require 'spec_helper'

describe Qtrix::Queue do
  before(:each) do
    queue_store.map_queue_weights a: 2, b: 3
  end

  let(:queue_store) { Qtrix::QueueStore.new(redis) }
  let(:all_queues) {queue_store.all_queues}
  let(:queue1) {all_queues[1]}
  let(:queue2) {all_queues[0]}

  context "comparing two queues with the same name and weights" do
    let(:other_queue) {Qtrix::Queue.new(:a, 2, 5)}
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
    let(:other_queue) {other_queue = Qtrix::Queue.new(:a, 3, 5)}
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
    let(:other_queue) {other_queue = Qtrix::Queue.new(:b, 2, 5)}
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

  describe "#relative_weight" do
    it "should equal weight / total weight of all queues" do
      queue1.relative_weight.should == 0.4
      queue2.relative_weight.should == 0.6
    end
  end
end
