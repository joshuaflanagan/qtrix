require 'singleton'
require 'redis-namespace'

module Qtrix
  ##
  # Provides support for namespacing the various redis keys so we can have multiple
  # configuration sets and a pointer to the current namespace or configuration set.
  #
  # This will allow for us to set up different configurations for different scenarios
  # and to switch between them easily.
  #
  # Scenarios might be things like:
  #
  # - day vs night configuration
  # - weekday vs weekend configuration
  # - common flood handling distributions.
  #
  # Most interaction should be through the mixin and not the manager singelton here.
  # Example:
  #
  # class Foo
  #   include Qtrix::Namespacing
  #   @redis_namespace = :foo  # or [:current, :foo]
  #
  #   def some_method
  #     redis.keys  # constrained to :qtrix:foo:*
  #   end
  # end
  module Namespacing
    def self.included(base)
      # make redis_key and current_namespaced available to both class and
      # instance methods
      base.instance_exec do
        extend Namespacing
      end
    end

    ##
    # Returns a redis client namespaced to the #redis_namespace defined in the
    # object/class, or to the id within the parent option.  An id of :current
    # will be evaluated to the current namespace.  By default, this
    # a root (qtrix:) namespaced client.  Examples:
    def redis(*namespaces)
      all_namespaces = redis_namespace + namespaces
      Manager.instance.redis(*all_namespaces)
    end

    ##
    # Returns the redis namespace as defined in the instance or class
    # @redis_namespace variable.
    def redis_namespace
      namespaces = Array(
        self.instance_variable_get(:@redis_namespace) ||
        self.class.instance_variable_get(:@redis_namespace)
      )
    end

    ##
    # Extracts the namespace, if any, from the arg list.
    def extract_args(arg_count, *args)
      if arg_count == args.size
        [:current] + args
      else
        args
      end
    end

    ##
    # Manages namespaces.  Uses Redis::Namespace to impose the namespacing
    # on calls to redis, and maintains the known config namespaces within
    # redis.  Should not be working directly with this too much, it should
    # be transparen when mixing in the Qtrix::Namespacing module.
    class Manager
      include Singleton
      NAMESPACING_KEY = :namespacing
      DEFAULT_NAMESPACE = :default
      attr_reader :connection_config

      def connection_config(opts={})
        @connection_config ||= opts
      end

      def redis(*namespaces)
        namespaced_client = Redis::Namespace.new(:qtrix, redis: client)
        namespaced_redis({redis: namespaced_client}, *evaluate(namespaces.uniq))
      end

      def add_namespace(namespace)
        validate namespace
        namespacing_redis.sadd(:namespaces, namespace)
      end

      def remove_namespace!(namespace)
        raise "Cannot remove default namespace" if namespace == :default
        raise "Cannot remove current namespace" if namespace == current_namespace
        namespacing_redis.srem(:namespaces, namespace)
        Qtrix::Override.clear!(namespace)
        Qtrix::Queue.clear!(namespace)
        Qtrix::Matrix.clear!(namespace)
      end

      def namespaces
        if default_namespace_does_not_exist?
          namespacing_redis.sadd(:namespaces, DEFAULT_NAMESPACE)
        end
        namespacing_redis.smembers(:namespaces).map{|ns| unpack(ns)}
      end

      def change_current_namespace(namespace)
        unless namespaces.include? namespace
          raise "Unknown namespace: #{namespace}"
        end
        if not_ready?(namespace)
          raise "#{namespace} is empty"
        end
        namespacing_redis.set(:current_namespace, namespace)
      end

      def current_namespace
        if no_current_namespace?
          self.change_current_namespace DEFAULT_NAMESPACE
        end
        unpack(namespacing_redis.get(:current_namespace))
      end

      private
      def not_ready?(namespace)
        namespace != :default &&
        Qtrix.desired_distribution(namespace).empty?
      end

      def evaluate(namespaces)
        ensure_a_namespace_in(namespaces)
        namespaces.map do |namespace|
          namespace == :current ? current_namespace : namespace
        end
      end

      def ensure_a_namespace_in(namespaces)
        if namespaces.compact.empty?
          namespaces << :current
        end
      end

      def client
        @client ||= Redis.connect(connection_config)
      end

      def namespacing_redis
        @namespacing_redis ||= redis(:namespacing)
      end

      def namespaced_redis(ctx, *namespaces)
        current, *others = namespaces
        if others.empty?
          if current
            Redis::Namespace.new(current, redis: ctx[:redis])
          else
            ctx[:redis]
          end
        else
          next_ctx = {redis: Redis::Namespace.new(current, redis: ctx[:redis])}
          namespaced_redis(next_ctx, *others)
        end
      end

      def validate(namespace)
        raise "cannot be nil" if namespace.nil?
        unless only_letters_numbers_and_underscores? namespace
          raise "must contain alphanumerics and underscores"
        end
        raise "#{namespace} already exists" if namespacing_redis.sismember(:namespaces, namespace)
      end

      def only_letters_numbers_and_underscores?(namespace)
        namespace =~ /^[\w\d_]+$/
      end

      def default_namespace_does_not_exist?
        !namespacing_redis.smembers(:namespaces).include? DEFAULT_NAMESPACE
      end

      def no_current_namespace?
        namespacing_redis.get(:current_namespace).nil?
      end

      def unpack(value)
        value.nil? ? nil : value.to_sym
      end

      def ensure_default_exists
        unless namespaces.include?(DEFAULT_NAMESPACE)
          self.add_namespace(DEFAULT_NAMESPACE)
        end
      end
    end
  end
end
