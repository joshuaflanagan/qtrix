require 'rspec/mocks'
require 'orchestrator'

RSpec.configure do |config|
  config.before(:each) do
    Orchestrator::Namespacing::Manager.instance.connection_config db: 15
    Orchestrator::Namespacing::Manager.instance.redis.flushdb
  end
end

def raw_redis
  Redis.connect db: 15
end

shared_context "an established matrix" do
  before do
    Orchestrator::Queue.map_queue_weights \
      A: 40,
      B: 30,
      C: 20,
      D: 10
    Orchestrator::Matrix.queues_for!('host1', 4)
  end
  let(:matrix) {Orchestrator::Matrix}
end

shared_context "established default and night namespaces" do
  let(:namespace_mgr) {Orchestrator::Namespacing::Manager.instance}
  before do
    namespace_mgr.change_current_namespace(:default)
    Orchestrator::Queue.map_queue_weights(A: 3, B: 2, C: 1)
    Orchestrator::Override.add([:C, :B, :A], 1)
    Orchestrator::Matrix.queues_for!('host1', 1)

    Orchestrator::Queue.all_queues.should_not be_empty
    Orchestrator::Override.all.should_not be_empty
    Orchestrator::Matrix.fetch.should_not be_empty

    namespace_mgr.add_namespace(:night)
    Orchestrator::Queue.map_queue_weights(:night, X: 4, Y: 2, Z: 1)
    Orchestrator::Override.add(:night, [:Z, :Y, :X], 1)
    Orchestrator::Matrix.queues_for!(:night, 'host1', 1)

    Orchestrator::Queue.all_queues(:night).should_not be_empty
    Orchestrator::Override.all(:night).should_not be_empty
    Orchestrator::Matrix.fetch(:night).should_not be_empty
  end
end
