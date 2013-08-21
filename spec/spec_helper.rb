require 'rspec/mocks'
require 'qtrix'

RSpec.configure do |config|
  config.before(:each) do
    Qtrix::Namespacing::Manager.instance.connection_config db: 15
    Qtrix::Namespacing::Manager.instance.redis.flushdb
  end
end

def raw_redis
  Redis.connect db: 15
end

shared_context "an established matrix" do
  before do
    Qtrix::Queue.map_queue_weights \
      A: 40,
      B: 30,
      C: 20,
      D: 10
    Qtrix::Matrix.queues_for!('host1', 4)
  end
  let(:matrix) {Qtrix::Matrix}
end

shared_context "established default and night namespaces" do
  let(:namespace_mgr) {Qtrix::Namespacing::Manager.instance}
  before do
    namespace_mgr.change_current_namespace(:default)
    Qtrix::Queue.map_queue_weights(A: 3, B: 2, C: 1)
    Qtrix::Override.add([:C, :B, :A], 1)
    Qtrix::Matrix.queues_for!('host1', 1)

    Qtrix::Queue.all_queues.should_not be_empty
    Qtrix::Override.all.should_not be_empty
    Qtrix::Matrix.fetch.should_not be_empty

    namespace_mgr.add_namespace(:night)
    Qtrix::Queue.map_queue_weights(:night, X: 4, Y: 2, Z: 1)
    Qtrix::Override.add(:night, [:Z, :Y, :X], 1)
    Qtrix::Matrix.queues_for!(:night, 'host1', 1)

    Qtrix::Queue.all_queues(:night).should_not be_empty
    Qtrix::Override.all(:night).should_not be_empty
    Qtrix::Matrix.fetch(:night).should_not be_empty
  end
end
