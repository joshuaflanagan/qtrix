require 'set'
require 'spec_helper'

describe Orchestrator do

  let(:namespace_manager) {Orchestrator::Namespacing::Manager.instance}

  describe "operations for configuration sets" do
    describe "#configuration_sets" do
      it "should return all namespaces" do
        Orchestrator.configuration_sets.should == [:default]
      end
    end

    describe "#create_configuration_set" do
      it "should create a namespace" do
        Orchestrator.create_configuration_set :weekend
        namespace_manager.namespaces.sort.should == [:default, :weekend]
      end
    end

    describe "#remove_configuration_set!" do
      it "should remove a namespace" do
        namespace_manager.add_namespace :daytime
        Orchestrator.remove_configuration_set! :daytime
        namespace_manager.namespaces.should == [:default]
      end
    end

    describe "#current_configuration_set" do
      it "should return the current namespace" do
        Orchestrator.current_configuration_set.should == :default
      end
    end

    describe "#activate_configuration_set!" do
      it "should set the current namespace" do
        namespace_manager.add_namespace :weekend
        Orchestrator.map_queue_weights :weekend, A: 10
        Orchestrator.activate_configuration_set! :weekend
        namespace_manager.current_namespace.should == :weekend
      end
    end
  end

  describe "#desired_distribution" do
    include_context "established default and night namespaces"
    let(:desired_dist) {Orchestrator.desired_distribution}
    let(:orchestrator_queues) {Set.new(desired_dist.map(&:name)).to_a}

    it "should include the list of known queues" do
      known_queues = Orchestrator::Queue.all_queues
      Orchestrator.desired_distribution.should == known_queues
    end

    it "should be constrainable to a config set." do
      known_queues = Orchestrator::Queue.all_queues :night
      Orchestrator.desired_distribution(:night).should == known_queues
    end
  end

  describe "#map_queue_weights" do
    include_context "established default and night namespaces"
    it "should persist the mappings of queues to weights" do
      Orchestrator.map_queue_weights \
        B: 0.3,
        A: 0.4,
        D: 0.1,
        C: 0.2
      effects = Orchestrator.desired_distribution
      effects.map(&:name).should == [:A, :B, :C, :D]
      effects.map(&:weight).should == [0.4, 0.3, 0.2, 0.1]
    end

    it "should be constrainable to a config set" do
      Orchestrator.map_queue_weights(:night, A: 100)
      known_queues = Orchestrator::Queue.all_queues :night
      Orchestrator.desired_distribution(:night).should == known_queues
    end
  end

  describe "override methods" do
    include_context "established default and night namespaces"
    def override_counts
      [Orchestrator::Override.all.size, Orchestrator::Override.all(:night).size]
    end

    let(:default_overrides) {Orchestrator::Override.all.map{|o| o.queues}}
    let(:night_overrides) {Orchestrator::Override.all(:night).map{|o| o.queues}}
    let(:default_size) {Orchestrator::Override.all.size}
    let(:night_size) {Orchestrator::Override.all(:night).size}

    describe "#add_override" do
      it "should persist the override to redis" do
        Orchestrator.add_override([:a, :b, :c], 2)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:a, :b, :c]]
      end

      it "should be directable to a config set" do
        default_before, night_before = override_counts
        Orchestrator.add_override(:night, [:abc], 2)
        default_after, night_after = override_counts
        default_after.should == default_before
        (night_after > night_before).should == true
      end
    end

    describe "#remove_override" do
      it "should remove the override from redis" do
        Orchestrator.add_override([:abc], 2)
        Orchestrator.remove_override([:abc], 2)
        default_overrides.select{|ql| ql == [:abc]}.should be_empty
      end

      it "should be directable to a config set" do
        Orchestrator.add_override(:night, [:abc], 2)
        default_before, night_before = override_counts
        Orchestrator.remove_override(:night, [:abc], 2)
        default_after, night_after = override_counts
        default_after.should == default_before
        (night_after < night_before).should == true
      end
    end

    describe "#overrides" do
      it "should return all overrides from redis" do
        Orchestrator.add_override([:a, :b, :c], 1)
        Orchestrator.add_override([:x, :y, :z], 1)
        default_overrides[-2..-1].should == [[:a, :b, :c], [:x, :y, :z]]
      end

      it "should be directable to a config set" do
        Orchestrator.add_override(:night, [:abc], 1)
        default_cnt, night_cnt = override_counts
        default_cnt.should == (night_cnt - 1)
      end
    end
  end

  describe "#queues_for!" do
    before(:each) do
      Orchestrator.map_queue_weights \
        A: 4,
        B: 3,
        C: 2,
        D: 1
    end

    context "no overrides" do
      it "should pick a queue list for a worker from the matrix" do
        result = Orchestrator.queues_for!('host1', 1)
        result.should == [[:A, :B, :C, :D, :__orchestrated__]]
      end
    end

    context "with overrides" do
      before(:each) do
        Orchestrator.add_override([:Z], 1)
      end

      context "when requesting queus for fewer or equal workers as there are overrides" do
        it "should pick a queue list from the overrides" do
          Orchestrator.queues_for!('host1', 1).should == [[:Z]]
        end
      end

      context "when requeues queues for more workers than there are overrides" do
        it "should choose queue lists from both overrides and the matrix" do
          Orchestrator.queues_for!('host1', 2)
            .should == [[:Z],[:A,:B,:C,:D,:__orchestrated__]]
        end
      end
    end

    context "across hosts" do
      it "it should appropriately distribute the queues." do
        first_expected = [[:A, :B, :C, :D, :__orchestrated__],
                          [:B, :A, :C, :D, :__orchestrated__]]
        Orchestrator.queues_for!('host1', 2).should == first_expected
        second_expected = [[:C, :A, :B, :D, :__orchestrated__],
                           [:D, :A, :B, :C, :__orchestrated__]]
        Orchestrator.queues_for!('host2', 2).should == second_expected
      end
    end
  end

  describe "#clear!" do
    let(:queue_key) {Orchestrator::Queue::REDIS_KEY}
    let(:override_key) {Orchestrator::Override::REDIS_KEY}
    let(:matrix_key) {Orchestrator::Matrix::REDIS_KEY}
    before do
      Orchestrator.map_queue_weights A: 0.4
      Orchestrator::Matrix.queues_for!("localhost", 2)
      Orchestrator.add_override([:D, :A, :B, :C], 1)
    end

    it "should clear redis of all keys related to orchestrator" do
      Orchestrator.clear!
      Orchestrator.redis.keys("#{matrix_key}*").should be_empty
      Orchestrator.redis.keys("#{queue_key}*").should_not be_empty
      Orchestrator.redis.keys("#{override_key}*").should_not be_empty
    end
  end
end
