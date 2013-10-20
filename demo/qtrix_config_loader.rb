require 'qtrix'

##
# Configuration loader for resque-pool that will interface
# with qtrix to obtain its config information.
class QtrixConfigLoader
  DEFAULT_POOL_SIZE = 5

  ##
  # Retrieve the configuration from Qtrix and pass back
  # as a properly formed resque-pool config hash.
  def call(env)
    queue_lists = queue_lists(pool_size)
    queue_lists.uniq.each_with_object({}) do |list, config|
      config[list] = count_times_in(queue_lists, list)
    end
  end

  private
  def count_times_in(queue_lists, element)
    queue_lists.select{|e| e == element}.size
  end

  def queue_lists(count)
    Qtrix.fetch_queues(hostname, count).map{|q| q.join(',')}
  end

  def hostname
    @hostname ||= Socket.gethostname
  end

  def pool_size
    ENV.fetch('POOL_SIZE', DEFAULT_POOL_SIZE).to_i
  end
end

# Wire up resque-pool & qtrix
Resque::Pool.after_prefork do |job|
  # We need to re-establish the client connection with each
  # worker fork.
  Resque.redis.client.reconnect
end

# This wires together resque-pool and qtrix
Resque::Pool.config_loader = QtrixConfigLoader.new
