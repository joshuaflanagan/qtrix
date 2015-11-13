require 'mixlib/cli'
require 'yaml'

module Qtrix
  module CLI
    class Base
      include Mixlib::CLI
      attr_reader :stdout, :stderr

      def initialize(stdout=STDOUT, stderr=STDERR)
        super()
        @stdout = stdout
        @stderr = stderr
      end

      def exec
        Qtrix.connection_config(config)
        unless exec_behavior
          msg = "no appropriate combination of options.\n\n"
          msg += "Type 'qtrix [command] --help' for usage"
          error(msg)
        end
      #rescue StandardError => e
        #error("Failure: #{e}")
      end

      private

      def write(msg)
        stdout.write("#{msg}\n")
        true
      end

      def error(msg)
        stderr.write("Failure: #{msg}\n")
        false
      end
    end

    class Default
      include Mixlib::CLI

      banner <<-EOS

Usage: qtrix [sub-command] [options]

Where available sub-commands are:

  queues:       Perform operations on queues
  overrides:    Perform operations on overrides

For more information about the subcommands, try:

  qtrix [subcommand] --help

      EOS
    end

    require 'qtrix/cli/queues'
    require 'qtrix/cli/overrides'

    @commands = {
      overrides:        Overrides,
      queues:           Queues,
    }

    def self.get_command_class(str)
      @commands.fetch(str.downcase.to_sym) if str
    end
  end
end

