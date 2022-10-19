require "test_helper"

class IntrospectTest < Minitest::Spec
  it "#find_path" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      sub_activity = Class.new(Trailblazer::Activity::Railway) do
        sub_activity = Class.new(Trailblazer::Activity::Railway) do
          step :c
        end

        step :b
        step Subprocess(sub_activity), id: :C
      end

      step :a
      step Subprocess(sub_activity), id: :B
    end

    node = Trailblazer::Developer::Introspect.find_path(activity, [:B, :C, :c])
    assert_equal node.class, Trailblazer::Activity::Introspect::Graph::Node
    assert_equal node.task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}

    assert_nil Trailblazer::Developer::Introspect.find_path(activity, [:c])
    assert_nil Trailblazer::Developer::Introspect.find_path(activity, [:B, :c])
  end
end
