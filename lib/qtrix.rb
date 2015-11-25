require 'qtrix/version'
require 'qtrix/client'
require 'qtrix/persistence'

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
  extend Logging
  ##
  # Specifies the redis connection configuration options as per the
  # redis gem.

  def self.instance
    @instance ||= Qtrix::Client.new(Persistence.redis)
  end

  def self.connection_config(opts={})
    Persistence.connection_config(opts)
  end

  ##
  # Returns the public operations of the facade.  Useful when tinkering
  # in a REPL.
  def self.operations
    self.public_methods - Module.public_methods
  end

  def self.desired_distribution
    instance.desired_distribution
  end

  def self.map_queue_weights(map)
    instance.map_queue_weights(map)
  end

  def self.add_override(*args)
    instance.add_override(*args)
  end

  def self.remove_override(*args)
    instance.remove_override(*args)
  end

  def self.overrides
    instance.overrides
  end

  def self.fetch_queues(hostname, workers, opts={})
    instance.fetch_queues(hostname, workers, opts)
  end

  ##
  # Clears redis of all information related to the orchestration system
  def self.clear!
    instance.clear!
  end

  def self.known_hosts
    instance.known_hosts
  end

  class ConfigurationError < StandardError; end
end
