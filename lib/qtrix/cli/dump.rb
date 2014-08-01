module Qtrix
  module CLI
    class Dump < Base
      banner <<-EOS

Usage: bundle exec qtrix dump

Dumps an executable script that will recreate all configuration
sets within a redis instance backing qtrix.  Useful for backup
purposes, or to maintain synchronization between environments
(prod, staging, etc...).

Options include:

      EOS

      option :file,
        short:       '-f PATH',
        long:        '--file PATH',
        description: 'Specify the file path to dump to',
        default:     './qtrix.dump'

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
        File.open(config[:file], "w") do |file|
          Qtrix.configuration_sets.each do |config_set|
            file.write(config_set_dump(config_set))
          end
        end
        FileUtils.chmod(0755, config[:file])
        write("Dumped all config-sets to #{config[:file]}.")
      end

      private
      def config_set_dump(name)
        "".tap do |result|
          unless name.to_sym == :default
            result << create_config_set_cmd(name)
          end
          result << map_queues_cmd(name)
          Qtrix.overrides(name).each do |override|
            result << override_cmd(override, name)
          end
        end
      end

      def create_config_set_cmd(cs)
        "#{command_start} config_sets --create #{cs} #{redis_options}\n"
      end

      def map_queues_cmd(cs)
        weights = Qtrix.desired_distribution(cs).map{|q| "#{q.name}:#{q.weight}"}.join(",")
        "#{command_start} queues -w #{weights} #{config_set(cs)} #{redis_options}\n"
      end

      def override_cmd(override, cs)
        "#{command_start} overrides -a -q #{override.queues.join(',')} " +
        "-w 1 #{config_set(cs)} #{redis_options}\n"
      end

      def command_start
        "bundle exec qtrix"
      end

      def config_set(name)
        "-c #{name}"
      end

      def redis_options
        "-h #{config[:host]} -p #{config[:port]} -n #{config[:db]}"
      end
    end
  end
end
