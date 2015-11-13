module Qtrix
  module CLI
    class Overrides < Base
      banner <<-EOS

Usage: qtrix overrides [options]

Allows interaction with the overrides. With this you can:

    * List all the overrides
    * Add overrides for a list of queues and number of workers.
    * Remove overrides for a list of queues and number of workers.

Options include:

      EOS

      option :list_overrides,
        short:       '-l',
        long:        '--list',
        description: 'List the queue overrides'

      option :add_overrides,
        short:       '-a',
        long:        '--add',
        description: 'Add a queue list override'

      option :delete_overrides,
        short:       '-d',
        long:        '--delete',
        description:  'Delete a queue list override, be sure to add -q <queue names>'

      option :queue_list,
        short:       '-q QUEUE_LIST',
        long:        '--queues QUEUE_LIST',
        description: 'Specify the list of queues for the override'

      option :workers,
        short:       '-w WORKER_COUNT',
        long:        '--workers WORKER_COUNT',
        description: 'Specify the list of workers for the override',
        default:     '1'

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
        if config[:list_overrides]
          msg = "Current Overrides:\n"
          msg += overrides.map(&stringify).join("\n")
          write(msg)
        elsif add_overrides_params_provided?
          Qtrix.add_override queue_list, workers
          write("Added #{workers} overrides for #{queue_list}")
        elsif delete_overrides_params_provided?
          Qtrix.remove_override queue_list, workers
          write("Deleted #{workers} overrides for #{queue_list}")
        end
      end

      private

      def stringify
        lambda {|override| string_value_of(override)}
      end

      def overrides
        Qtrix.overrides
      end

      def string_value_of(override)
        "  #{hostname_of(override)}: #{override.queues.join(',')}"
      end

      def hostname_of(override)
        override.host || 'Unclaimed'
      end

      def add_overrides_params_provided?
        config[:add_overrides] && queues_and_workers?
      end

      def delete_overrides_params_provided?
        config[:delete_overrides] && queues_and_workers?
      end

      def queues_and_workers?
        config[:queue_list] && config[:workers]
      end

      def queue_list
        config[:queue_list].split(",").map(&:strip)
      end

      def workers
        config[:workers].to_i
      end
    end
  end
end
