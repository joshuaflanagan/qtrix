require 'mixlib/cli'
require 'yaml'

module Orchestrator
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
        Orchestrator.connection_config(config)
        unless exec_behavior
          msg = "no appropriate combination of options.\n\n"
          msg += "Type 'bundle exec [command] --help' for usage"
          error(msg)
        end
      rescue StandardError => e
        error("Failure: #{e}")
      end

      private
      def to_args(*args)
        args.compact
      end

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

Usage: bundle exec orchestrate [sub-command] [options]

Where available sub-commands are:

  config-sets:  Perform operations on configuration sets.
  queues:       Perform operations on queues within a
                configuration set.
  overrides:    Perform operations on overrides within a
                configuration set.

For more information about the subcommands, try:

  bundle exec orchestrate [subcommand] --help

      EOS
    end

    require 'orchestrator/cli/config_sets'
    require 'orchestrator/cli/queues'
    require 'orchestrator/cli/overrides'

    @commands = {
      config_sets: ConfigSets,
      overrides:   Overrides,
      queues:      Queues
    }

    def self.get_command_class(str)
      @commands.fetch(str.downcase.to_sym) if str
    end
  end
end

