module Orchestrator
  module CLI
    class ConfigSets < Base
      include Mixlib::CLI

      banner <<-EOS

Usage: bundle exec orchestrate config_sets [options]

Allows interaction with the configuration sets in the orchestrator system.
With this, you can:

    * View all configuration sets.
    * View the current configuration set.
    * Add a configuration set.
    * Specify the current configuration set.
    * Remove a configuration set.

Options include:

      EOS

      option :list,
        short:       '-l',
        long:        '--list',
        description: 'The list of known config sets'

      option :current_configuration_set,
        short:       '-c',
        long:        '--current',
        description: 'List current config set'

      option :add_configuration_set,
        long:        '--create CONFIG_SET_NAME',
        description: 'Create a new config set'

      option :activate_configuration_set,
        short:       '-a CONFIG_SET_NAME',
        long:        '--activate CONFIG_SET_NAME',
        description: 'Activate a configuration set'

      option :remove_configuration_set,
        short:       '-d CONFIG_SET_NAME',
        long:        '--delete CONFIG_SET_NAME',
        description: 'Delete a non-active config set'

      option :host,
        short:       '-h HOST',
        description: 'The host where redis is located',
        default:     'localhost'

      option :port,
        short:       '-p PORT',
        description: 'The host which redis is listening on',
        default:     6379

      option :db,
        short:       '-n DB',
        description: 'The redis DB where the action should occur',
        default:     0

      def exec_behavior
        if config[:list]
          config_sets = Orchestrator.configuration_sets
          msg = "Known configuration sets: #{config_sets.join(", ")}"
          write(msg)
        elsif config[:current_configuration_set]
          current_config_set = Orchestrator.current_configuration_set
          msg = "Current configuration set: #{current_config_set}"
          write(msg)
        elsif config[:add_configuration_set]
          config_set = config[:add_configuration_set]
          Orchestrator.create_configuration_set(config_set)
          write("Configuration set created successfully: #{config_set}")
        elsif config[:activate_configuration_set]
          config_set = config[:activate_configuration_set].to_sym
          Orchestrator.activate_configuration_set!(config_set)
          write("Activated configuration set successfully: #{config_set}")
        elsif config[:remove_configuration_set]
          config_set = config[:remove_configuration_set]
          Orchestrator.remove_configuration_set!(config_set.to_sym)
          write("Configuration set removed successfully: #{config_set}")
        end
      end
    end
  end
end
