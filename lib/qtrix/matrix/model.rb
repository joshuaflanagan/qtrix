require 'bigdecimal'

module Qtrix
  class Matrix
    class Model
      attr_reader :rows, :added_rows, :deleted_rows
      def initialize(rows)
        @rows = rows
        @added_rows = []
        @deleted_rows = []
      end

      def to_table
        @rows.map{|row| row.entries.map(&:queue)}
      end

      def row_count
        @rows.length
      end

      def rows_for_host(hostname)
        @rows.select{|row| row.hostname == hostname}
      end

      def add_row(row)
        @added_rows << row
        @rows << row
      end

      def remove_row_for_host(hostname)
        index_to_remove = @rows.rindex{|row| row.hostname == hostname}
        # raise if no row found?
        return unless index_to_remove
        removed_row = @rows.delete_at(index_to_remove)
        deleted_rows << removed_row
        removed_row
      end
    end

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
