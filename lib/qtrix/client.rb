require 'qtrix/logging'
require 'qtrix/persistence'
require 'qtrix/queue_store'
require 'qtrix/override_store'
require 'qtrix/queue'
require 'qtrix/override'
require 'qtrix/matrix'
require 'qtrix/host_manager'
require 'qtrix/locking'

##
# Facade into a dynamically adjusting global worker pool that auto
# balances workers according to a desired distribution of resources
# for each queue.
#
# The desired distribution can be modified in real time, and the
# workers throughout our global pool across all servers should morph
# to reflect the new desired distribution.  Further details on how
# desired distribution is achieved can be found in the
# lib/qtrix/matrix.rb comments.
#
# Overrides should be able to be specified, so that we can say
# out of all of our workers, N should specifically service this list
# of queues.  This is for flood event handling -- a queue gets flooded
# and we need to direct resources to it to help process the jobs faster.
#
# This is the primary entry point to the system, a GUI, CLI or script
# meant to interact with the system should probably work through this
# module

module Qtrix
  class Client
    include Logging

    attr_reader :redis

    def initialize(redis)
      @redis = redis
    end

    ##
    # Returns a list of objects that define the desired distribution
    # of workers.  Each element will contain the queue name, weight, and
    # relative_weight (weight / total weight of all queues).

    def desired_distribution
      queue_store.all_queues
    end

    ##
    # Specifies the queue/weight mapping table.
    # This will be used to generate the queue list for workers and thus the
    # desired distribution of resources to queues.  Args can be:
    #
    # map: the queue-to-weight mappings as a hash of queue names to
    #      float values.

    def map_queue_weights(map)
      with_lock do
        queue_store.map_queue_weights(map)
      end
    rescue Exception => e
      error(e)
      raise
    end

    ##
    # Add a list of queue names to use as an override for a number
    # of worker processes.  The number of worker processes will be removed from
    # the desired distribution and start working the list of queues in the
    # verride. args should be:
    #
    # queues:  Array of queue names.
    # processes:  Integer specifying the number of workers
    # to override queues for.

    def add_override(queues, processes)
      with_lock do
        override_store.add(queues, processes)
        matrix_store.clear!
        true
      end
    rescue Exception => e
      error(e)
      raise
    end

    ##
    # Removes an override.
    # That number of worker processes will quit servicing the queues in the
    # override and be brought back into servicing the desired distribution.
    # Args can be:
    #
    # queues:  Array of queues in the override.
    # processes:  Number of processes to remove from overriding.

    def remove_override(queues, processes)
      with_lock do
        override_store.remove(queues, processes)
        matrix_store.clear!
        true
      end
    rescue Exception => e
      error(e)
      raise
    end

    def clear_overrides
      with_lock do
        override_store.clear!
        matrix_store.clear!
        true
      end
    rescue Exception => e
      error(e)
      raise
    end

    ##
    # Retrieves all currently defined overrides.

    def overrides
      override_store.all
    end

    ##
    # Retrieves lists of queues as appropriate to the overall system balance
    # for the number of workers specified for the given +hostname+.

    def fetch_queues(hostname, workers, opts={})
      host_manager.ping(hostname)
      clear_matrix_if_any_hosts_offline
      with_lock timeout: opts.fetch(:timeout, 5), on_timeout: last_result do
        debug("fetching #{workers} queue lists for #{hostname}")
        overrides_queues = override_store.overrides_for(hostname, workers)
        debug("overrides for #{hostname}: #{overrides_queues}")
        delta = workers - overrides_queues.size
        matrix_queues = delta > 0 ? matrix_store.update_matrix_to_satisfy_request!(hostname, delta) : []
        debug("matrix queue lists: #{matrix_queues}")
        orchestrated_flag = [:__orchestrated__]
        new_result = overrides_queues + matrix_queues.map{|q| q + orchestrated_flag}
        info("queue lists changed") if new_result != @last_result
        debug("list details: #{new_result}")
        @last_result = new_result
      end
    rescue Exception => e
      error(e)
      raise
    end

    ##
    # Clears redis of all information related to the orchestration system
    def clear!
      with_lock do
        info "clearing data"
        override_store.clear_claims!
        host_manager.clear!
        matrix_store.clear!
      end
    end

    def known_hosts
      host_manager.all
    end

    private

    def host_manager
      @host_manager ||= HostManager.new(redis)
    end

    def queue_store
      @queue_store ||= QueueStore.new(redis)
    end

    def locker
      @locker ||= Qtrix::Locking.new(redis)
    end

    def matrix_store
      @matrix_store ||= Qtrix::Matrix.new(redis)
    end

    def override_store
      @override_store ||= Qtrix::OverrideStore.new(redis)
    end

    def with_lock(*args, &block)
      locker.with_lock(*args, &block)
    end

    def last_result
      lambda do
        if @last_result
          @last_result
        else
          raise "no previous result (unable to obtain lock on first attempt)"
        end
      end
    end

    def clear_matrix_if_any_hosts_offline
      if host_manager.any_offline?
        info "hosts detected offline: #{host_manager.offline.join(', ')}"
        clear!
      end
    end
  end
end
