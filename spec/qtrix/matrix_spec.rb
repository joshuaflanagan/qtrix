require 'spec_helper'
require 'set'

describe Qtrix::Matrix do
  before do
    Qtrix::Queue.map_queue_weights(A: 3, B: 2, C: 1)
    Qtrix::Matrix.fetch_queues('host1', 1)
  end

  let(:matrix) {Qtrix::Matrix}

  describe "#fetch" do
    it "should return the entire matrix as stored" do
      result = matrix.fetch.map{|row| row.entries.map(&:queue)}.sort
      result.should == [[:A, :B, :C]]
    end
  end

  describe "#to_table" do
    it "should return the rows of queue lists" do
      matrix.to_table.should == [[:A, :B, :C]]
    end
  end

  describe "#clear!" do
    it "should clear all data related to the matrix" do
      matrix.clear!
      raw_redis.keys("qtrix:default:matrix*").should == []
    end
  end

  describe "#fetch_queues" do
    it "should return an ordered list of queues for the given host" do
      matrix.fetch_queues("host1", 1).should == [[:A, :B, :C]]
    end

    it "should auto-shuffle distribution of queues if they all have the same weight" do
      pending "This spec is flawed (and fails with ruby 2 change)"
      # I'm guessing the intended behavior is that the returned lists of queues
      # should be mostly unique, with minimal duplicates.
      # However, the spec assertion really only checks the number of lists
      # that have duplicates, *not* how many rows are represented by those duplicates.
      # In fact, the current algorithm only returns 7 unique lists (5 to make sure
      # each queue starts a list, and then 2 more repeated 95 times).
      # With 5 distinct queues, there are 120 (5 factorial) possible combinations,
      # so an optimal algorithm would return 100 unique lists when 100 rows
      # are requested.
      Qtrix.map_queue_weights A: 1, B: 1, C: 1, D: 1, E: 1
      matrix.fetch_queues("host1", 100)
      rows = matrix.to_table[5..-1]
      dupes = Set.new
      while(current_row = rows.shift) do
        next if dupes.include? current_row
        if rows.detect{|another_row| another_row == current_row}
          dupes.add(current_row)
        end
      end
      dupes.size.should be < 10
    end
  end
end
