require 'set'
require 'spec_helper'

describe Qtrix do
  describe "#desired_distribution" do
    include_context "established qtrix configuration"
    let(:desired_dist) {Qtrix.desired_distribution}
    let(:qtrix_queues) {Set.new(desired_dist.map(&:name)).to_a}

    it "should include the list of known queues" do
      known_queues = Qtrix::Queue.all_queues
      Qtrix.desired_distribution.should == known_queues
    end
  end

  describe "#map_queue_weights" do
    include_context "established qtrix configuration"
    it "should persist the mappings of queues to weights" do
      Qtrix.map_queue_weights \
        B: 0.3,
        A: 0.4,
        D: 0.1,
        C: 0.2
      effects = Qtrix.desired_distribution
      effects.map(&:name).should == [:A, :B, :C, :D]
      effects.map(&:weight).should == [0.4, 0.3, 0.2, 0.1]
    end
  end

  describe "override methods" do
    include_context "established qtrix configuration"
    def override_counts
      [Qtrix::Override.all.size]
    end

    let(:default_overrides) {Qtrix::Override.all.map{|o| o.queues}}
    let(:default_size) {Qtrix::Override.all.size}

    describe "#add_override" do
      it "should persist the override to redis" do
        Qtrix.add_override([:a, :b, :c], 2)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:a, :b, :c]]
      end
    end

    describe "#remove_override" do
      it "should remove the override from redis" do
        Qtrix.add_override([:abc], 2)
        Qtrix.remove_override([:abc], 2)
        default_overrides.select{|ql| ql == [:abc]}.should be_empty
      end
    end

    describe "#overrides" do
      it "should return all overrides from redis" do
        Qtrix.add_override([:a, :b, :c], 1)
        Qtrix.add_override([:x, :y, :z], 1)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:x, :y, :z]]
      end
    end
  end

  describe "#fetch_queues" do
    let(:override_claims_key) {Qtrix::Override::REDIS_CLAIMS_KEY}
    context "with queue weightings" do
      before(:each) do
        Qtrix.map_queue_weights \
          A: 4,
          B: 3,
          C: 2,
          D: 1
      end

      it "should treat the request as a ping from the host" do
        Qtrix.fetch_queues('host1', 1)
        Qtrix::HostManager.all.should == ['host1']
      end

      it "should return previous results if it cannot obtain a lock" do
        result = Qtrix.fetch_queues('host1', 1)
        result.should == [[:A, :B, :C, :D, :__orchestrated__]]

        Qtrix.map_queue_weights Z: 1
        redis.set :lock, Qtrix::Persistence.redis_time + 15

        result = Qtrix.fetch_queues('host1', 1)
        result.should == [[:A, :B, :C, :D, :__orchestrated__]]
      end

      context "no overrides" do
        it "should pick a queue list for a worker from the matrix" do
          result = Qtrix.fetch_queues('host1', 1)
          result.should == [[:A, :B, :C, :D, :__orchestrated__]]
        end

        it "should not add any override claims" do
          Qtrix.fetch_queues('host1', 2)
          redis.llen(override_claims_key).should == 0
        end
      end

      context "and overrides" do
        before(:each) do
          Qtrix.add_override([:Z], 1)
        end

        context "when requesting queues for fewer or equal workers as there are overrides" do
          it "should pick a queue list from the overrides only" do
            Qtrix.fetch_queues('host1', 1).should == [[:Z]]
          end
        end

        context "when requesting queues for more workers than there are overrides" do
          it "should choose queue lists from both overrides and the matrix" do
            Qtrix.fetch_queues('host1', 2)
            .should == [[:Z],[:A,:B,:C,:D,:__orchestrated__]]
          end
        end

        it "should not result in more override claims than configured overrides when requests come from single host " do
          (0..5).each {Qtrix.fetch_queues('host1', 2)}
          redis.llen(override_claims_key).should == 1
        end

        it "should not result in more override claims than configured overrides when requests come from mutliple hosts" do
          Qtrix.fetch_queues('host1', 1)
          (0..5).each { Qtrix.fetch_queues('host2', 2) }
          redis.llen(override_claims_key).should == 1
        end

        it "should rebalance the matrix when hosts have been detected to be offline" do
          start_time = Qtrix::Persistence.redis_time
          Qtrix.fetch_queues('host1', 2).first.should == [:Z]
          Qtrix.fetch_queues('host2', 2).first.should_not == [:Z]

          Qtrix::Persistence.stub(:redis_time) {start_time + 60}
          Qtrix.fetch_queues('host2', 2)
          Qtrix::Persistence.stub(:redis_time) {start_time + 121}
          Qtrix.fetch_queues('host2', 2).first.should == [:Z]
        end
      end

      context "across hosts" do
        it "it should appropriately distribute the queues." do
          first_expected = [[:A, :B, :C, :D, :__orchestrated__],
                            [:B, :A, :C, :D, :__orchestrated__]]
          Qtrix.fetch_queues('host1', 2).should == first_expected
          second_expected = [[:C, :A, :B, :D, :__orchestrated__],
                             [:D, :A, :B, :C, :__orchestrated__]]
          Qtrix.fetch_queues('host2', 2).should == second_expected
        end
      end
    end

    context "with no queue weightings defined" do
      context "and no overrides" do
        it "should raise a configuration error" do
          expect {
            Qtrix.fetch_queues('host1', 1)
          }.to raise_error Qtrix::ConfigurationError
        end
      end
      context "and overrides added" do
        before(:each) do
          Qtrix.add_override([:Z], 1)
        end

        context "when requesting queues for fewer or equal workers as there are overrides" do
          it "should pick a queue list from the overrides only" do
            Qtrix.fetch_queues('host1', 1).should == [[:Z]]
          end
        end

        context "when requesting queues for more workers than there are overrides" do
          it "should raise a configuration error" do
            expect {
              Qtrix.fetch_queues('host1', 2)
            }.to raise_error Qtrix::ConfigurationError
          end
        end
      end
    end
  end

  describe "#clear!" do
    let(:queue_key) {Qtrix::Queue::REDIS_KEY}
    let(:override_key) {Qtrix::Override::REDIS_KEY}
    let(:override_claims_key) {Qtrix::Override::REDIS_CLAIMS_KEY}
    let(:matrix_key) {Qtrix::Matrix::REDIS_KEY}
    let(:known_hosts_key) {Qtrix::HostManager::REDIS_KEY}

    before do
      Qtrix.map_queue_weights A: 0.4
      Qtrix.add_override([:D, :A, :B, :C], 1)
      Qtrix.fetch_queues("localhost", 2)
      redis.keys(matrix_key).should_not be_empty
      redis.keys(override_claims_key).should_not be_empty
      redis.keys(known_hosts_key).should_not be_empty
    end

    it "should clear redis of all keys related to qtrix" do
      Qtrix.clear!
      redis.keys(matrix_key).should be_empty
      redis.keys(override_claims_key).should be_empty
      redis.keys(known_hosts_key).should be_empty
      redis.keys(queue_key).should_not be_empty
      redis.keys(override_key).should_not be_empty
    end
  end
end
