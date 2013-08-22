module Qtrix
  module CLI
    class Queues < Base
      banner <<-EOS

Usage: bundle exec qtrix queues [options]

Allows observance and manipulation of queue priority within a
configuration set.  With this you can:

    * View the current queue priority in the global worker pool.
    * Specify the weightings for all queues inline or via yaml

Options include:

      EOS

      option :queue_weights,
        short:       '-w',
        long:        '--weights QUEUE_WEIGHT_LIST',
        description: 'Specifies the queue-weight mappings as queue:weight,queue:weight,...'

      option :queue_weights_yaml,
        short:       '-y',
        long:        '--yaml PATH_TO_YAML',
        description: 'Path to a yaml containing a hash of queue names to weights'

      option :desired_distribution,
        short:       '-l',
        long:        '--list',
        description: 'Lists the queues by their desired distribution'

      option :config_set,
        short:       '-c CONFIG_SET_NAME',
        long:        '--config-set CONFIG_SET_NAME',
        description: 'Specify the config set being operated on'

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
        if config[:desired_distribution]
          desired_dist = Qtrix.desired_distribution(config[:config_set])
          msg = "Queues:\n"
          msg += desired_dist.map(&stringify).join("\n")
          write(msg)
        elsif queue_weights
          map_queue_weights queue_weights
        elsif queue_weights_yaml
          map_queue_weights queue_weights_yaml
        end
      end

      private
      def map_queue_weights(weight_map)
        Qtrix.map_queue_weights *to_args(config_set, weight_map)
        write("OK")
      end

      def stringify
        lambda {|queue| "  #{queue.name} (#{queue.weight})"}
      end

      def string_value_of(queue)
        "  #{q.name} (#{q.weight})"
      end

      def queue_weights
        if config[:queue_weights]
          tuple_list = config[:queue_weights].split(",").map{|kv| kv.split(":")}
          Hash[tuple_list]
        end
      end

      def queue_weights_yaml
        if config[:queue_weights_yaml]
          YAML.load(File.read(config[:queue_weights_yaml]))
        end
      end

      def config_set
        config[:config_set]
      end
    end
  end
end
