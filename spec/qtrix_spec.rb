require 'set'
require 'spec_helper'

describe Qtrix do

  let(:namespace_manager) {Qtrix::Namespacing::Manager.instance}

  describe "operations for configuration sets" do
    describe "#configuration_sets" do
      it "should return all namespaces" do
        Qtrix.configuration_sets.should == [:default]
      end
    end

    describe "#has_configuration_set?" do
      it "should return true if the passed config set exists" do
        Qtrix.has_configuration_set?(:default).should == true
      end

      it "should return false if the passed config set does not exist" do
        Qtrix.has_configuration_set?(:foo).should == false end
    end

    describe "#create_configuration_set" do
      it "should create a namespace" do
        Qtrix.create_configuration_set :weekend
        namespace_manager.namespaces.sort.should == [:default, :weekend]
      end
    end

    describe "#remove_configuration_set!" do
      it "should remove a namespace" do
        namespace_manager.add_namespace :daytime
        Qtrix.remove_configuration_set! :daytime
        namespace_manager.namespaces.should == [:default]
      end
    end

    describe "#current_configuration_set" do
      it "should return the current namespace" do
        Qtrix.current_configuration_set.should == :default
      end
    end

    describe "#activate_configuration_set!" do
      it "should set the current namespace" do
        namespace_manager.add_namespace :weekend
        Qtrix.map_queue_weights :weekend, A: 10
        Qtrix.activate_configuration_set! :weekend
        namespace_manager.current_namespace.should == :weekend
      end
    end

    describe "#clone_configuration_set" do
      before(:each) do
        Qtrix.map_queue_weights A: 10
        Qtrix.add_override [:Z], 1
      end

      it "should fail if source is not specified" do
        expect{Qtrix.clone_configuration_set nil, :bar}.to raise_error
      end

      it "should fail if dest is not specified" do
        expect{Qtrix.clone_configuration_set :default, nil}.to raise_error
      end

      it "should fail if source does not exist" do
        expect{Qtrix.clone_configuration_set :foo, :bar}.to raise_error
      end

      it "should fail if dest already exists" do
        expect{Qtrix.clone_configuration_set :default, :default}.to raise_error
      end

      it "should create the destination config set" do
        Qtrix.clone_configuration_set :default, :foo
        Qtrix.has_configuration_set?(:foo).should == true
      end

      it "should copy queue weights to the clone" do
        Qtrix.clone_configuration_set :default, :foo
        Qtrix.desired_distribution(:foo).should ==
          Qtrix.desired_distribution(:default)
      end

      it "should copy overrides to the clone" do
        Qtrix.clone_configuration_set :default, :foo
        Qtrix.overrides(:foo).should ==
          Qtrix.overrides(:default)
      end
    end
  end

  describe "#desired_distribution" do
    include_context "established default and night namespaces"
    let(:desired_dist) {Qtrix.desired_distribution}
    let(:qtrix_queues) {Set.new(desired_dist.map(&:name)).to_a}

    it "should include the list of known queues" do
      known_queues = Qtrix::Queue.all_queues
      Qtrix.desired_distribution.should == known_queues
    end

    it "should be constrainable to a config set." do
      known_queues = Qtrix::Queue.all_queues :night
      Qtrix.desired_distribution(:night).should == known_queues
    end
  end

  describe "#map_queue_weights" do
    include_context "established default and night namespaces"
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

    it "should be constrainable to a config set" do
      Qtrix.map_queue_weights(:night, A: 100)
      known_queues = Qtrix::Queue.all_queues :night
      Qtrix.desired_distribution(:night).should == known_queues
    end
  end

  describe "override methods" do
    include_context "established default and night namespaces"
    def override_counts
      [Qtrix::Override.all.size, Qtrix::Override.all(:night).size]
    end

    let(:default_overrides) {Qtrix::Override.all.map{|o| o.queues}}
    let(:night_overrides) {Qtrix::Override.all(:night).map{|o| o.queues}}
    let(:default_size) {Qtrix::Override.all.size}
    let(:night_size) {Qtrix::Override.all(:night).size}

    describe "#add_override" do
      it "should persist the override to redis" do
        Qtrix.add_override([:a, :b, :c], 2)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:a, :b, :c]]
      end

      it "should be directable to a config set" do
        default_before, night_before = override_counts
        Qtrix.add_override(:night, [:abc], 2)
        default_after, night_after = override_counts
        default_after.should == default_before
        (night_after > night_before).should == true
      end
    end

    describe "#remove_override" do
      it "should remove the override from redis" do
        Qtrix.add_override([:abc], 2)
        Qtrix.remove_override([:abc], 2)
        default_overrides.select{|ql| ql == [:abc]}.should be_empty
      end

      it "should be directable to a config set" do
        Qtrix.add_override(:night, [:abc], 2)
        default_before, night_before = override_counts
        Qtrix.remove_override(:night, [:abc], 2)
        default_after, night_after = override_counts
        default_after.should == default_before
        (night_after < night_before).should == true
      end
    end

    describe "#overrides" do
      it "should return all overrides from redis" do
        Qtrix.add_override([:a, :b, :c], 1)
        Qtrix.add_override([:x, :y, :z], 1)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:x, :y, :z]]
      end

      it "should be directable to a config set" do
        Qtrix.add_override(:night, [:abc], 1)
        default_cnt, night_cnt = override_counts
        default_cnt.should == (night_cnt - 1)
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


      context "no overrides" do
        it "should pick a queue list for a worker from the matrix" do
          result = Qtrix.fetch_queues('host1', 1)
          result.should == [[:A, :B, :C, :D, :__orchestrated__]]
        end

        it "should not add any override claims" do
          Qtrix.fetch_queues('host1', 2)
          Qtrix::Override.redis.llen(override_claims_key).should == 0
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
          Qtrix::Override.redis.llen(override_claims_key).should == 1
        end

        it "should not result in more override claims than configured overrides when requests come from mutliple hosts" do
          Qtrix.fetch_queues('host1', 1)
          (0..5).each { Qtrix.fetch_queues('host2', 2) }
          Qtrix::Override.redis.llen(override_claims_key).should == 1
        end

        it "should rebalance the matrix when hosts have been detected to be offline" do
          start_time = Qtrix::HostManager.server_time
          Qtrix.fetch_queues('host1', 2).first.should == [:Z]
          Qtrix.fetch_queues('host2', 2).first.should_not == [:Z]

          Qtrix::HostManager.stub(:server_time) {start_time + 5}
          Qtrix.fetch_queues('host2', 2)
          Qtrix::HostManager.stub(:server_time) {start_time + 10}
          Qtrix.fetch_queues('host2', 2)
          Qtrix::HostManager.stub(:server_time) {start_time + 15}
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
      Qtrix.redis.keys(matrix_key).should_not be_empty
      Qtrix.redis.keys(override_claims_key).should_not be_empty
      Qtrix.redis.keys(known_hosts_key).should_not be_empty
    end

    it "should clear redis of all keys related to qtrix" do
      Qtrix.clear!
      Qtrix.redis.keys(matrix_key).should be_empty
      Qtrix.redis.keys(override_claims_key).should be_empty
      Qtrix.redis.keys(known_hosts_key).should be_empty
      Qtrix.redis.keys(queue_key).should_not be_empty
      Qtrix.redis.keys(override_key).should_not be_empty
    end
  end
end
