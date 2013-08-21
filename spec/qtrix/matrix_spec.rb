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

    describe "#queues_for!" do
      context "with no namespace specified" do
        it "should return queues from current namespace" do
          matrix.queues_for!("host1", 1).should == [[:A, :B, :C]]
        end

        it "should auto-shuffle distribution of queues if they all have the same weight" do
          Qtrix.map_queue_weights A: 1, B: 1, C: 1, D: 1, E: 1
          matrix.queues_for!("host1", 100)
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
          matrix.queues_for!(:night, "host1", 1).should == [[:X, :Y, :Z]]
        end
      end
    end
  end
end
