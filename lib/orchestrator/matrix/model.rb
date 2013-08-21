require 'bigdecimal'
require 'orchestrator/matrix/common'

module Orchestrator
  module Matrix
    ##
    # An entry (or cell) in the matrix, contains a single queue and its value
    # relative to the other entries to the left in the same row.
    Entry = Struct.new(:queue, :resource_percentage, :value)

    ##
    # A row in the matrix, contains the hostname the row is for and the entries
    # of queues within the row.
    Row = Struct.new(:hostname, :entries)
  end
end
