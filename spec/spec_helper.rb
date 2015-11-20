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
