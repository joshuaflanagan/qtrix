require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'rspec/mocks'
require 'qtrix'

RSpec.configure do |config|
  config.before(:each) do
    Qtrix::Persistence.instance.connection_config db: 15
    raw_redis.flushdb
  end
end

def raw_redis
  Redis.connect db: 15
end

def redis
  Qtrix::Persistence.redis
end

shared_context "an established matrix" do
  before do
    Qtrix::Queue.map_queue_weights \
      A: 40,
      B: 30,
      C: 20,
      D: 10
    Qtrix::Matrix.fetch_queues('host1', 4)
  end
  let(:matrix) {Qtrix::Matrix}
end

shared_context "established qtrix configuration" do
  before do
    Qtrix::Queue.map_queue_weights(A: 3, B: 2, C: 1)
    Qtrix::Override.add([:C, :B, :A], 1)
    Qtrix::Matrix.fetch_queues('host1', 1)

    Qtrix::Queue.all_queues.should_not be_empty
    Qtrix::Override.all.should_not be_empty
    Qtrix::Matrix.fetch.should_not be_empty
  end
end
