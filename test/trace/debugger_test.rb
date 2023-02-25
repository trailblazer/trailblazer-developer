require "test_helper"

class DebuggerTest < Minitest::Spec
  it "what" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(
      sub_activity_options: {id: "B"}, _activity_options: {id: "C"})

    # We want to change the Railway[:activity] field, which is the {Activity} instance seen at runtime.
    _activity.to_h[:activity].instance_variable_set(:@special, true) # FIXME: don't kill me for this horrible flag.


    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{seq: []}, {}])

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

  #@ particular nodes need a special {runtime_id}
    my_compute_runtime_id = ->(ctx, captured_node:, activity:, compile_id:, **) do
      return compile_id unless activity.instance_variable_get(:@special)

      ctx[:runtime_id] = compile_id.to_s*9
    end

    captured_input_for_activity     = stack.to_a.find { |captured| captured.task == activity }
    captured_input_for_sub_activity = stack.to_a.find { |captured| captured.task == sub_activity }

    #@ this is internal API but we're never gonna need this anywhere except for other internals :)
    pipeline_extension = Trailblazer::Activity::TaskWrap::Extension.build([
      Dev::Trace::Debugger::Normalizer.Task(my_compute_runtime_id),
      id: :my_compute_runtime_id,
      append: :runtime_id # so that the following {#runtime_path} picks up those changes made here.
    ])
    extended_normalizer = pipeline_extension.(Dev::Trace::Debugger::Normalizer::PIPELINES.last)


    debugger_nodes = Dev::Trace::Debugger::Node.build_for_stack(
      stack,
      normalizer: extended_normalizer,
      node_options: {
    #@ we can pass particular label "hints".
        captured_input_for_activity => {
          label: %{#{activity.superclass} (anonymous)},
        },
  #@ we may pass Node.data options (keyed by Stack::Captured)
        captured_input_for_sub_activity => {
          data: {
            exception_source: true
          }
        }
      }, # node_options
    )

    assert_equal debugger_nodes[0].task, activity
    assert_equal debugger_nodes[0].activity, Trailblazer::Activity::TaskWrap.container_activity_for(activity)

    assert_equal debugger_nodes[0].task, activity
    assert_equal debugger_nodes[0].compile_id, nil
    assert_equal debugger_nodes[0].compile_path, []
    assert_equal debugger_nodes[0].runtime_id, nil
    assert_equal debugger_nodes[0].runtime_path, []
    assert_equal debugger_nodes[0].level, 0
    assert_equal debugger_nodes[0].label, %{Trailblazer::Activity::Railway (anonymous)}
    assert_equal debugger_nodes[0].data, {}
    assert_equal debugger_nodes[0].captured_input, stack.to_a[0]
    assert_equal debugger_nodes[0].captured_output, stack.to_a[-1]

    assert_equal debugger_nodes[1].activity.class, Trailblazer::Activity # The [activity] field is an Activity.
    assert_equal debugger_nodes[1].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_equal debugger_nodes[1].compile_id, %{Start.default}
    assert_equal debugger_nodes[1].compile_path, ["Start.default"]
    assert_equal debugger_nodes[1].runtime_path, ["Start.default"]
    assert_equal debugger_nodes[1].runtime_id, %{Start.default}
    assert_equal debugger_nodes[1].level, 1
    assert_equal debugger_nodes[1].label, %{Start.default}
    assert_equal debugger_nodes[1].data, {}
    assert_equal debugger_nodes[1].captured_input, stack.to_a[1]
    assert_equal debugger_nodes[1].captured_output, stack.to_a[2]

    assert_equal debugger_nodes[3].task, sub_activity
    # the "parent activity" for {sub_activity} is not the Activity::Railway class but instance of Acivity.
    assert_equal debugger_nodes[3].activity.class, Trailblazer::Activity
    assert_equal debugger_nodes[3].activity, debugger_nodes[1].activity
    assert_equal debugger_nodes[3].data, {exception_source: true}
    assert_equal debugger_nodes[3].runtime_path, ["B"]

    assert_equal debugger_nodes[9].compile_id, :d
    assert_equal debugger_nodes[9].compile_path, ["B", "C", :d]
    assert_equal debugger_nodes[9].runtime_id, "ddddddddd"
    assert_equal debugger_nodes[9].runtime_path, ["B", "C", "ddddddddd"]
    assert_equal debugger_nodes[9].level, 3
    assert_equal debugger_nodes[9].label, %{ddddddddd}
    assert_equal debugger_nodes[9].data, {}
    assert_equal debugger_nodes[9].captured_input, stack.to_a[15]
    assert_equal debugger_nodes[9].captured_output, stack.to_a[16]
    assert_equal debugger_nodes[9].captured_input.data[:ctx_snapshot], {:seq=>"[:a, :b, :c]"}
    assert_equal debugger_nodes[9].captured_output.data[:ctx_snapshot], {:seq=>"[:a, :b, :c, :d]"}
  end

  it "add {runtime_id} normalizer task" do
    my_compute_runtime_id = ->(ctx, captured_node:, activity:, compile_id:, **) do
      # activity is the host activity
      return compile_id unless activity.to_h[:config][:each] == true
      index = captured_node.captured_input.data[:ctx].fetch(:index)

      ctx[:runtime_id] = "#{compile_id}.#{index}"
    end

    Trailblazer::Developer::Trace::Debugger.add_normalizer_step!(my_compute_runtime_id, id: "compile_id.Each")
  end
end
