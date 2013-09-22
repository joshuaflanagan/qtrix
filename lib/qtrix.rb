require 'qtrix/version'
require 'qtrix/namespacing'
require 'qtrix/queue'
require 'qtrix/override'
require 'qtrix/matrix'
require 'qtrix/host_manager'

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
# Different configuration sets should be supported, with one being
# active at a time.  A configuration set is a namespaced desired
# distribution and set of overrides.
#
# This is the primary entry point to the system, a GUI, CLI or script
# meant to interact with the system should probably work through this
# module

module Qtrix
  include Namespacing
  ##
  # Specifies the redis connection configuration options as per the
  # redis gem.

  def self.connection_config(opts={})
    Namespacing::Manager.instance.connection_config(opts)
  end

  ##
  # Returns the public operations of the facade.  Useful when tinkering
  # in a REPL.
  def self.operations
    self.public_methods - Namespacing.methods - Namespacing.instance_methods
  end

  ##
  # Returns the list of all configuration sets that have been
  # created

  def self.configuration_sets
    Namespacing::Manager.instance.namespaces
  end

  ##
  # Creates a configuration set for use in the system, which
  # can have its own desired distribution and overrides.

  def self.create_configuration_set(namespace)
    Namespacing::Manager.instance.add_namespace(namespace)
  end

  ##
  # Removes a configuration set from the system, it will
  # no longer be able to be activated to change the behavior
  # of the system as a whole.

  def self.remove_configuration_set!(namespace)
    Namespacing::Manager.instance.remove_namespace!(namespace)
  end

  ##
  # Returns the current configuration set in use by the system.

  def self.current_configuration_set
    Namespacing::Manager.instance.current_namespace
  end

  ##
  # Specifies the current configuration set.  The namespace must identify
  # a configuration set created with create_configuration_set.

  def self.activate_configuration_set!(namespace)
    Namespacing::Manager.instance.change_current_namespace(namespace)
  end

  ##
  # Returns a list of objects that define the desired distribution
  # of workers for the current configuration set.  Each element
  # will contain the queue name, weight, and resource_percentage
  # (weight / total weight of all queues).  By default, this operated
  # on the current configuration set.

  def self.desired_distribution(config_set=:current)
    Queue.all_queues(config_set)
  end

  ##
  # Specifies the queue/weight mapping table for a configuration
  # set.  This will be used to generate the queue list for workers
  # and thus the desired distribution of resources to queues.  Args
  # can be:
  #
  # config_set: optional, defaults to current.
  # map: the queue-to-weight mappings as a hash of queue names to
  #      float values.

  def self.map_queue_weights(*args)
    config_set, map = extract_args(1, *args)
    Qtrix::Queue.map_queue_weights(config_set, map)
  end

  ##
  # Add a list of queue names to use as an override for a number
  # of worker processes in a configuration set.  The number of
  # worker processes will be removed from the desired distribution
  # and start working the list of queues in the override. args
  # should be:
  #
  # configuration_set: optional, defaults to :current.
  # queues:  Array of queue names.
  # processes:  Integer specifying the number of workers
  # to override queues for.

  def self.add_override(*args)
    config_set, queues, processes = extract_args(2, *args)
    Qtrix::Override.add(config_set, queues, processes)
    true
  end

  ##
  # Removes an override from a current configuration set.  That
  # number of worker processes will quit servicing the queues in the
  # override and be brought back into servicing the desired distribution.
  # Args can be:
  #
  # configuration_set: optional, defaults to :current.
  # queues:  Array of queues in the override.
  # processes:  Number of processes to remove from overriding.

  def self.remove_override(*args)
    config_set, queues, processes = extract_args(2, *args)
    Qtrix::Override.remove(config_set, queues, processes)
    true
  end

  ##
  # Retrieves all currently defined overrides within a config set.
  # Defaults to use the current config set.

  def self.overrides(config_set=:current)
    Qtrix::Override.all(config_set)
  end

  ##
  # Retrieves lists of queues as appropriate to the overall system balance
  # for the number of workers specified for the given +hostname+.

  def self.fetch_queues(hostname, workers)
    overrides_queues = Qtrix::Override.overrides_for(hostname, workers)
    delta = workers - overrides_queues.size
    matrix_queues = delta > 0 ? Matrix.fetch_queues(hostname, delta) : []
    overrides_queues + matrix_queues.map(&append_orchestrated_flag)
  end

  ##
  # Clears redis of all information related to the orchestration system

  def self.clear!
    Matrix.clear!
  end

  private
  def self.append_orchestrated_flag
    lambda {|queue_lists| queue_lists << :__orchestrated__}
  end

  class ConfigurationError < StandardError; end
end
