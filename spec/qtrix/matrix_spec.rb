require 'spec_helper'
require 'set'

describe Qtrix::Matrix do
  before do
    queue_store.map_queue_weights(A: 3, B: 2, C: 1)
    matrix_store.update_matrix_to_satisfy_request!('host1', 1)
  end

  let(:matrix_store) {Qtrix::Matrix.new(redis)}
  let(:queue_store) {Qtrix::QueueStore.new(redis)}

  describe "#fetch" do
    it "should return the entire matrix as stored" do
      result = matrix_store.fetch.to_table.sort
      result.should == [[:A, :B, :C]]
    end
  end

  describe "#clear!" do
    it "should clear all data related to the matrix" do
      matrix_store.clear!
      raw_redis.keys("qtrix:default:matrix*").should == []
    end
  end

  describe "#update_matrix_to_satisfy_request!" do
    it "should return an ordered list of queues for the given host" do
      matrix_store.update_matrix_to_satisfy_request!("host1", 1).should == [[:A, :B, :C]]
    end
  end
end
