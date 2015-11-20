require 'spec_helper'

describe Qtrix::QueueStore do
  let(:matrix_store) {Qtrix::Matrix.new(redis)}
  subject(:queue_store) { Qtrix::QueueStore.new(redis) }

  before(:each) do
    queue_store.map_queue_weights a: 2, b: 3
  end

  describe "#map_queue_weights" do
    it "should remove old queues" do
      queue_store.map_queue_weights A: 100
      result = queue_store.all_queues.map(&:name)
      result.include?(:B).should_not be_true
      result.include?(:C).should_not be_true
    end

    it "should add new queues ordered according to weight" do
      queue_store.map_queue_weights(A: 3, B: 2, C: 1)
      results = queue_store.all_queues
      results.map(&:name).should == [:A, :B, :C]
      results.map(&:weight).should == [3, 2, 1]
    end

    it "should error when trying to save empty queue name" do
      expect{queue_store.map_queue_weights('' => 1)}.to raise_error
    end

    it "should error when trying to save nil weight" do
      expect{queue_store.map_queue_weights(c: nil)}.to raise_error
    end

    it "should error when trying to save weight of 0" do
      expect{queue_store.map_queue_weights(c: 0)}.to raise_error
    end

    it "should error when trying to save weight of > 1000" do
      expect{queue_store.map_queue_weights(d: 1000)}.to raise_error
    end

    it "should blow away the matrix" do
      matrix_store.fetch_queues('host1', 1)
      matrix_store.to_table.should_not be_empty
      queue_store.map_queue_weights \
        A: 1,
        B: 2
      matrix_store.to_table.should be_empty
    end
  end

  describe "#all_queues" do
    describe "with no distributions defined" do
      it "should raise a configuration error" do
        queue_store.clear!
        expect {
          queue_store.all_queues
        }.to raise_error Qtrix::ConfigurationError
      end
    end
    it "should contain all queues sorted by weight desc" do
      queue_store.map_queue_weights(A: 3, B: 2, C: 1)
      queue_store.all_queues.map(&:name).should == [:A, :B, :C]
    end
  end

  describe "#to_map" do
    it "should return a map containing all queue names mapped to their weights" do
      map = {A: 10, B: 4}
      queue_store.map_queue_weights(map)
      queue_store.to_map.should == map
    end
  end

  describe "#count" do
    it "should be the number of queues mapped" do
      queue_store.map_queue_weights(A: 3, B: 2, C: 1)
      queue_store.count.should == 3
    end
  end

  describe "#clear!" do
    before(:each) {queue_store.clear!}
    it "should remove all existing queue weights" do
      redis.exists(Qtrix::Queue::REDIS_KEY).should_not == true
    end

    it "should blow away the matrix" do
      matrix_store.to_table.should be_empty
    end
  end
end
