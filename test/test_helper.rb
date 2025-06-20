$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"
require "trailblazer/core"

require "minitest/autorun"
require "pp"

require "trailblazer/invoke" # FIXME: remove me, this should be done on library level.

require "trailblazer/activity/dsl/linear"
require "trailblazer/activity/testing"
puts "Running in Ruby #{RUBY_VERSION}"

T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  let(:kernel) do
    Class.new do
      Trailblazer::Invoke.module!(self)
    end.new
  end

  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  CU = Trailblazer::Core::Utils

  Dev = Trailblazer::Developer
  include Trailblazer::Activity::Testing::Assertions

  Implementing = T.def_tasks(:b, :e, :B, :C)

  let(:flat_activity) do
    Class.new(Trailblazer::Activity::Path) do
      step task: Implementing.method(:B), id: :B
      step task: Implementing.method(:C), id: :C
    end
  end

  let(:nested_activity) do
    flat_activity = self.flat_activity

    Class.new(Trailblazer::Activity::Path) do
      step task: Implementing.method(:b),
        id: :B,
        more: true,
        DataVariable() => :more
      step Subprocess(flat_activity), id: :D
      step task: Implementing.method(:e), id: :E
    end
  end

  module Tracing
    def self.three_level_nested_activity(sub_activity_options: {}, _activity_options: {}, e_options: {})
      sub_activity = nil
      _activity    = nil

      activity = Class.new(Trailblazer::Activity::Railway) do
        include T.def_steps(:a, :e)

        sub_activity = Class.new(Trailblazer::Activity::Railway) do
          include T.def_steps(:b)
          _activity = Class.new(Trailblazer::Activity::Railway) do
            include T.def_steps(:c, :d)
            step :c
            step :d
          end

          step :b
          step Subprocess(_activity), **_activity_options
        end

        step :a
        step Subprocess(sub_activity), **sub_activity_options
        step :e, e_options
      end

      return activity, sub_activity, _activity
    end

    class ValidateWithRescue < Trailblazer::Activity::Railway
      def self.rescue((ctx, flow_options), runner:, **circuit_options)
        begin
          signal, (ctx, flow_options) = runner.(Validate, [ctx, flow_options],
            runner: runner,
            **circuit_options.merge(activity: Trailblazer::Activity::TaskWrap.container_activity_for(Validate)))
        rescue

        end

        return Trailblazer::Activity::Right, [ctx, flow_options]
      end

      step task: method(:rescue)


      class Validate < Trailblazer::Activity::Railway
        step :validate
        def validate(ctx, validate: false, seq:, **)
          seq << :validate
          raise unless validate
          validate
        end
      end
    end
  end # Tracing
end
