class BaseJob
  ##
  # Performs a job by sleeping for a time and
  # incrementing the count of times performed
  # in redis (key is the job class name)
  def self.perform(sleep_time=0)
    sleep(sleep_time)
    Resque.redis.incr class_name
  end

  private
  def self.redis
    @redis ||= Redis.new
  end

  def self.class_name
    self.to_s
  end
end

class ImportJob < BaseJob
  @queue = :imports
end

class ExportJob < BaseJob
  @queue = :exports
end

class EmailJob < BaseJob
  @queue = :emails
end

class AuditJob < BaseJob
  @queue = :audits
end
