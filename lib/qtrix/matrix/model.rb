require 'bigdecimal'
require 'qtrix/matrix/common'

module Qtrix
  module Matrix
    ##
    # An entry (or cell) in the matrix, contains a single queue and its value
    # relative to the other entries to the left in the same row.
    Entry = Struct.new(:queue, :resource_percentage, :value) do
      def to_s
        "#{queue}(#{value},#{resource_percentage})"
      end
    end

    ##
    # A row in the matrix, contains the hostname the row is for and the entries
    # of queues within the row.
    Row = Struct.new(:hostname, :entries) do
      def to_s
        "#{hostname}: #{entries.join(', ')}"
      end
    end
  end
end
