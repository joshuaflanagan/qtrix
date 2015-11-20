require 'bigdecimal'
require 'qtrix/matrix/common'
require 'qtrix/matrix/model'
require 'qtrix/matrix/queue_picker'
require 'qtrix/matrix/reader'
require 'qtrix/matrix/row_builder'
require 'qtrix/matrix/queue_prioritizer'
require 'qtrix/matrix/analyzer'

module Qtrix
  ##
  # Represents the matrix of queues to workers across the global worker pool,
  # and is used to assign queues to pools based on the following goals:
  #
  # 1.  Maintain a desired distribution of worker resources to queues based
  #     on their weight within the system as a whole.
  # 2.  Ensure that every queue is at the head of at least 1 workers queue
  #     list.
  #
  # Given a queue's weight, we calculate its resource percentage as:
  #
  # weight_of(queue) / weight_of(all_queues)
  #
  # To generate the list of queues for a worker, we take a list of queues
  # sorted by current priority.  The current priority is calculated in one of
  # two ways.  If the queue has not been at the head of the list, it is
  # calculated as:
  #
  # resource_percentage_of(queue) * 1000
  #
  # This inflated value ensures that we will assign all queues to the head of
  # at least one worker's queue list.
  #
  # If a queue has not been assigned to the head of a worker's queue list,
  # the following algortihm is used.  Each entry in the matrix has a value,
  # which is generally the likelihood that the queue would be reached given
  # the weight of jobs to its left in a queue list.  Mathematically, this is:
  #
  # 1.0 - resource_percentage_of(previous_queues_in_list)
  #
  # Thus the closer to the head of a list a queue's entry is, the higher a
  # value it receives for that entry.  The priority is then calculated as:
  #
  # resource_percentage_of(queue) / (1.0 + value_of(entries_for(queue))
  #
  # This ensures that the higher a queue appears in a list, the lower its
  # priority for the next generated list.

  module Matrix
    include Common
    extend Logging

    class << self
      ##
      # Obtain lists of queues for a number of worker processes
      # on a server identified by the hostname.
      def fetch_queues(*args)
        hostname, workers = *args
        QueuePicker.new(Reader, hostname, workers).pick!
      end

      ##
      # Returns all of the queues in the table.
      def fetch
        Reader.fetch
      end

      ##
      # Fetches a matrix of simple queue names for each entry.
      def to_table
        Reader.to_table
      end

      ##
      # Clears the matrix so its rebuilt again when rows are requested.
      def clear!
        debug("what if I told you I was clearing the matrix?")
        Persistence.redis.del(REDIS_KEY)
      end
    end
  end
end

