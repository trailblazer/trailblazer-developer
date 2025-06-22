# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"

require "minitest/autorun"
require "pp"

require "trailblazer/activity"
require "trailblazer/activity/testing"
require "trailblazer/activity/dsl/linear"
puts "Running in Ruby #{RUBY_VERSION}"

T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  Dev = Trailblazer::Developer
  include Trailblazer::Activity::Testing::Assertions

  Implementing = T.def_tasks(:b, :e, :B, :C)

  # Helper to check hash inspect output across Ruby versions
  # Ruby >= 3.4 uses {:key=>value} syntax, older versions use {key: value}
  def assert_hash_inspect(actual, expected_old_syntax)
    if RUBY_VERSION >= "3.4"
      # Convert old syntax to new syntax for comparison
      expected_new_syntax = expected_old_syntax.gsub(/(\w+): /, ':\1=>')
      assert_equal actual, expected_new_syntax
    else
      assert_equal actual, expected_old_syntax
    end
  end

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
          signal, (ctx, flow_options) = runner.(Validate, [ctx, flow_options], runner: runner, **circuit_options)
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
