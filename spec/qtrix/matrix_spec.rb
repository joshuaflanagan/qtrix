require 'spec_helper'
require 'set'

describe Qtrix::Matrix do
  describe "namespaced operations" do
    include_context "established default and night namespaces"
    let(:matrix) {Qtrix::Matrix}

    describe "#fetch" do
      it "should default to the current namespace" do
        result = matrix.fetch.map{|row| row.entries.map(&:queue)}.sort
        result.should == [[:A, :B, :C]]
      end

      it "should allow fetching from a different namespace" do
        result = matrix.fetch(:night).map{|row| row.entries.map(&:queue)}.sort
        result.should == [[:X, :Y, :Z]]
      end
    end

    describe "#to_table" do
      it "should default to the current namespace" do
        matrix.to_table.should == [[:A, :B, :C]]
      end

      it "should allow fetching from a different namespace" do
        matrix.to_table(:night).should == [[:X, :Y, :Z]]
      end
    end

    describe "#clear!" do
      it "should default to the current namespace" do
        matrix.clear!
        raw_redis.keys("qtrix:default:matrix*").should == []
      end

      it "should allow clearing of a different namespace" do
        matrix.clear! :night
        raw_redis.keys("qtrix:night:matrix*").should == []
      end
    end

    describe "#fetch_queues" do
      context "with no namespace specified" do
        it "should return queues from current namespace" do
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

      context "with namespace specified" do
        it "should return queues from the specified namespace" do
          matrix.fetch_queues(:night, "host1", 1).should == [[:X, :Y, :Z]]
        end
      end
    end
  end
end
