require 'spec_helper'

class DummyJob
  @queue = :test_queue
end

describe Qtrix::Queue do
  include Qtrix::Namespacing
  before(:each) do
    Qtrix::Queue.map_queue_weights a: 2, b: 3
  end
  let(:all_queues) {Qtrix::Queue.all_queues}
  let(:queue1) {all_queues[1]}
  let(:queue2) {all_queues[0]}
  let(:matrix) {Qtrix::Matrix}

  context "comparing two queues with the same name and weights" do
    let(:other_queue) {Qtrix::Queue.new(:current, :a, 2)}
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
    let(:other_queue) {other_queue = Qtrix::Queue.new(:current, :a, 3)}
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
    let(:other_queue) {other_queue = Qtrix::Queue.new(:default, :b, 2)}
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
    include_context "established default and night namespaces"
    describe "#map_queue_weights" do
      context "no namespace specified" do
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

        it "should blow away the matrix" do
          matrix.queues_for!('host1', 1)
          matrix.to_table.should_not be_empty
          Qtrix::Queue.map_queue_weights \
            A: 1,
            B: 2
          matrix.to_table.should be_empty
        end
      end

      context "namespace specified" do
        it "should affect targetted namespace" do
          Qtrix::Queue.map_queue_weights :night, Z: 10, X: 1, Y: 5
          Qtrix::Queue.all_queues(:night).map(&:name).should == [:Z, :Y, :X]
        end
      end
    end

    describe "#all_queues" do
      describe "with no namepsace specified" do
        it "should contain all queues in the default ns sorted by weight desc" do
          Qtrix::Queue.all_queues.map(&:name).should == [:A, :B, :C]
        end
      end

      describe "with namespace specified" do
        it "should contain all queues in the default ns sorted by weight desc" do
          result = Qtrix::Queue.all_queues(:night)
          result.map(&:name).should == [:X, :Y, :Z]
        end
      end
    end

    describe "#count" do
      context "with no namespace specified" do
        it "should be the number of queues mapped in the current namespace" do
          Qtrix::Queue.count.should == 3
        end
      end
      context "with namespace specifeid" do
        it "should be the number of queues mapped in the target namespace" do
          Qtrix::Queue.map_queue_weights(:night, a: 2)
          Qtrix::Queue.count(:night).should == 1
        end
      end
    end

    describe "#total_weight" do
      context "with no namespace specified" do
        it "should contain the sum of all weights" do
          Qtrix::Queue.total_weight == 6
        end
      end

      context "with namespace provided" do
        it "should contain the sum of all weights in the namespace" do
          Qtrix::Queue.total_weight(:night) == 7
        end
      end
    end

    describe "#clear!" do
      context "with no namespace specified" do
        before(:each) {Qtrix::Queue.clear!}
        it "should remove all existing queue weights" do
          redis.exists(Qtrix::Queue::REDIS_KEY).should_not == true
        end

        it "should blow away the matrix" do
          matrix.to_table.should be_empty
        end
      end

      context "with namespace specified" do
        before(:each) {Qtrix::Queue.clear! :night}
        it "should remove all existing queue weights" do
          redis(:night).exists(Qtrix::Queue::REDIS_KEY).should_not == true
        end

        it "should blow away the matrix" do
          matrix.to_table(:night).should be_empty
        end
      end
    end
  end
end
