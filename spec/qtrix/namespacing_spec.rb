require 'spec_helper'

describe Qtrix::Namespacing do
  include Qtrix::Namespacing
  let(:test_class) {
    class Foo < Object
      include Qtrix::Namespacing
    end
  }
  let(:test_instance) {test_class.new}

  shared_examples_for "@redis_namespace definers #redis" do
    it "should return redis connection namespaced to :a" do
      target.redis.namespace.should == :a
    end

    it "should allow caller to specify namespacing" do
      target.redis(:b, :c).set("d", 1)
      result = raw_redis.keys.reject{|key| key[/namespace/]}
      result.should == ["qtrix:default:a:b:c:d"]
    end
  end

  [:test_class, :test_instance].each do |target_name|
    context "for #{target_name}" do
      let(:target) {send(target_name)}

      describe "#redis" do
        context "without @redis_namespace defined in self or self.class" do
          it "should return redis connection namespaced to :default" do
            target.redis.namespace.should == :default
          end

          it "should allow caller to specify namespacing" do
            target.redis(:a, :b).set("c", 1)
            raw_redis.keys.include?("qtrix:a:b:c").should == true
          end

          it "should evaluate caller arg of :current to the current namespace" do
            target.redis(:current).set("a", 1)
            result = raw_redis.keys.select{|key| key[/default/]}
            result.should == ["qtrix:default:a"]
          end
        end

        context "with @redis_namespace defined in self" do
          around(:each) do |example|
            target.send(:instance_variable_set, :@redis_namespace, [:current, :a])
            example.run
            target.send(:instance_variable_set, :@redis_namespace, nil)
          end

          it_should_behave_like "@redis_namespace definers #redis"
        end

        context "with @redis_namespace defined in class" do
          around(:each) do |example|
            target.class.send(:instance_variable_set, :@redis_namespace, [:current, :a])
            example.run
            target.class.send(:instance_variable_set, :@redis_namespace, nil)
          end

          it_should_behave_like "@redis_namespace definers #redis"
        end
      end

      describe "#redis_namespace" do
        context "without @redis_namespace defined in self or self.class" do
          it "should return nil" do
            target.redis_namespace.should == []
          end
        end

        context "with @redis_namespace defined" do
          around(:each) do |example|
            target.send(:instance_variable_set, :@redis_namespace, [:current, :foo])
            example.run
            target.send(:instance_variable_set, :@redis_namespace, nil)
          end

          it "should return self@redis_namespace" do
            target.redis_namespace.should == [:current, :foo]
          end
        end

        context "with @redis_namespace defined in superclass" do
          around(:each) do |example|
            target.class.send(:instance_variable_set, :@redis_namespace, [:current, :foo])
            example.run
            target.class.send(:instance_variable_set, :@redis_namespace, nil)
          end

          it "should return class@redis_namespace" do
            target.redis_namespace.should == [:current, :foo]
          end
        end
      end
    end
  end

  describe Qtrix::Namespacing::Manager do
    let(:manager) {Qtrix::Namespacing::Manager.instance}

    describe "#redis" do
      context "with no args passed" do
        it "should return a redis connection with no args" do
          manager.redis.keys.should_not be_nil
        end

        it "should return a redis connection namespaced to qtrix:default" do
          manager.redis.namespace.should == :default
        end
      end

      context "with args passed" do
        it "each arg should be a namespace for keys defined in redis" do
          manager.redis(:foo, :bar).set("a", 1)
          raw_redis.keys.include?("qtrix:foo:bar:a").should == true
        end

        it "should prune out any duplicate namespaces" do
          manager.redis(:a, :a, :a).set("b", 1)
          result = raw_redis.keys.grep(/qtrix:a/)
          result.should == ["qtrix:a:b"]
        end
      end
    end

    describe "#add_namespace" do
      it "should add a namespace to the system" do
        manager.add_namespace(:night_distribution)
        manager.namespaces.sort.should == [:default, :night_distribution]
      end

      it "should error when nil passed" do
        expect{manager.add_namespace(nil)}.to raise_error
      end

      it "should error when valid pattern is not matched" do
        expect{manager.add_namespace('#$*#($')}.to raise_error
      end

      it "should error when attempting to add an existing namespace" do
        manager.namespaces.should_not be_empty
        expect{manager.add_namespace(:default)}.to raise_error
      end
    end

    describe "#remove_namesapce" do
      include_context "an established matrix"
      before {manager.add_namespace(:transition_flood)}

      it "should remove a namespace from the system" do
        manager.remove_namespace!(:transition_flood)
        manager.namespaces.should == [:default]
      end

      it "should not allow you to delete the default namespace" do
        expect{manager.remove_namespace!(:default)}.to raise_error
      end

      it "should not allow you to remove the current namespace" do
        Qtrix.map_queue_weights(:transition_flood, A: 1)
        manager.change_current_namespace(:transition_flood)
        expect{manager.remove_namespace!(:transition_flood)}.to raise_error
      end

      describe "cascading removal" do
        before do
          Qtrix.add_override(:transition_flood, ["A"], 1)
          Qtrix.map_queue_weights :transition_flood, B: 10
          Qtrix::Matrix.queues_for!(:transition_flood, "host1", 2)
        end

        it "should cascade deletes to data in the namespace" do
          manager.remove_namespace!(:transition_flood)
          raw_redis.keys("qtrix:transition_flood*").should == []
        end
      end
    end

    describe "#current_namespace" do
      it "should default to :default" do
        manager.current_namespace.should == :default
      end
    end

    describe "#change_current_namespace" do
      include_context "an established matrix"
      before(:each) {manager.add_namespace(:night_distribution)}

      it "should set the current namespace" do
        Qtrix.map_queue_weights(:night_distribution, A: 1)
        manager.change_current_namespace(:night_distribution)
        manager.current_namespace.should == :night_distribution
      end

      it "should error if trying to set the namespace to something unknown" do
        expect{manager.change_current_namespace :foo}.to raise_error
      end

      it "should error if trying to change into an empty namespace" do
        expect{manager.change_current_namespace(:night_distribution)}.to raise_error
      end
    end
  end
end
