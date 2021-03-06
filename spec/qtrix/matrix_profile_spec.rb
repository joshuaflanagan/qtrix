require 'spec_helper'
require 'rspec-prof'

describe Qtrix::Matrix do
  # For this test's purpose, a queues receives a score each time it appears
  # in a row within the matrix -- 4 for being at the head of a row, 3 for
  # being the next queue in the row, 2 for being the 3rd queue in the row
  # and 1 for being the last queue in the row.
  def cumulative_score_of(queue)
    matrix = matrix_store.fetch.to_table
    scores = matrix.map{|row| 4 - row.index(queue)}
    scores.inject(0) {|m, s| m += s}
  end

  def head_count_of(target_queue)
    matrix = matrix_store.fetch.to_table
    heads = matrix.map{|row| row[0]}
    heads.select{|queue| queue == target_queue}.size
  end

  let(:a_score) {cumulative_score_of(:A)}
  let(:b_score) {cumulative_score_of(:B)}
  let(:c_score) {cumulative_score_of(:C)}
  let(:d_score) {cumulative_score_of(:D)}
  let(:a_heads) {head_count_of(:A)}
  let(:b_heads) {head_count_of(:B)}
  let(:c_heads) {head_count_of(:C)}
  let(:d_heads) {head_count_of(:D)}
  let(:matrix) {matrix_store.fetch.to_table}
  let(:matrix_store) { Qtrix::Matrix.new(redis) }

  # Check to make sure that the following holds true for 4, 10 and 100
  # worker setups:
  #
  # 1.  every queue is at the head of a worker list at least once.
  # 2.  queues with a higher weight occur more frequently to the left of queues
  #     with a lower weight in the list of queues processed by all workers.
  [2,5,50].each do |worker_count|
    context "managing #{worker_count*2} workers across 2 hosts" do
      # The following will generate profiling reports in the profiles dir.
      around(:each) do |example|
        RSpecProf.profile("profiles/#{example.metadata[:description_args].first.gsub(/\s+/,'_')}.html") do
          example.run
        end
      end
      before (:each) do
        matrix_store.clear!
        Qtrix.map_queue_weights \
          A: 40,
          B: 30,
          C: 20,
          D: 10
        matrix_store.update_matrix_to_satisfy_request!('host1', worker_count)
        matrix_store.update_matrix_to_satisfy_request!('host2', worker_count)
      end

      it "should maintain the desired distribution of queues" do
        a_score.should be >= b_score
        b_score.should be >= c_score
        c_score.should be >= d_score
      end

      it "should have every queue at the head of at least one worker queue list" do
        a_heads.should_not == 0
        b_heads.should_not == 0
        c_heads.should_not == 0
        d_heads.should_not == 0
      end

      it "should maintain desired distribution of queues at the head of queue lists" do
        a_heads.should be >= b_heads
        b_heads.should be >= c_heads
        c_heads.should be >= d_heads
      end

      it "should not have any duplicate queues in any rows" do
        matrix.each do |row|
          row.should == row.uniq
        end
      end
    end
  end
end
