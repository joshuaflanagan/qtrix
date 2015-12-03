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
