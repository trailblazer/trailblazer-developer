require "test_helper"

class DebuggerTest < Minitest::Spec
  it "deprecates {:captured_node}" do
    my_compute_runtime_id = ->(ctx, captured_node:, **) do
      captured_node.snapshot_after # throw an exception.
    end

    pipeline_extension = Trailblazer::Activity::TaskWrap::Extension.build([
      Dev::Debugger::Normalizer.Task(my_compute_runtime_id),
      id: :my_compute_runtime_id,
      append: :data
    ])
    extended_normalizer = pipeline_extension.(Dev::Debugger::Normalizer::PIPELINES.last)

    activity = Class.new(Trailblazer::Activity::Railway) do
      step :create
    end

    exception = assert_raises do
      Dev.wtf?(activity, [{}, {}], present_options: {normalizer: extended_normalizer})
    end

    assert_equal exception.message, %([Trailblazer] The `:captured_node` argument is deprecated, please upgrade to `trailblazer-developer-0.1.0` and use `:trace_node` if the upgrade doesn't fix it.)
  end

  it "what" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(
      sub_activity_options: {id: "B"}, _activity_options: {id: "C"})

    # We want to change the Railway[:activity] field, which is the {Activity} instance seen at runtime.
    _activity.to_h[:activity].instance_variable_set(:@special, true) # FIXME: don't kill me for this horrible flag.


    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{seq: []}, {}])

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

  #@ particular nodes need a special {runtime_id}
    my_compute_runtime_id = ->(ctx, trace_node:, activity:, compile_id:, **) do
      return compile_id unless activity.instance_variable_get(:@special)

      ctx[:runtime_id] = compile_id.to_s*9
    end

    snapshot_before_for_activity     = stack.to_a.find { |captured| captured.task == activity }
    snapshot_before_for_sub_activity = stack.to_a.find { |captured| captured.task == sub_activity }

    #@ this is internal API but we're never gonna need this anywhere except for other internals :)
    pipeline_extension = Trailblazer::Activity::TaskWrap::Extension.build([
      Dev::Debugger::Normalizer.Task(my_compute_runtime_id),
      id: :my_compute_runtime_id,
      append: :runtime_id # so that the following {#runtime_path} picks up those changes made here.
    ])
    extended_normalizer = pipeline_extension.(Dev::Debugger::Normalizer::PIPELINES.last)


    nodes = Dev::Debugger.trace_for_stack(
      stack,
      normalizer: extended_normalizer,
      node_options: {
    #@ we can pass particular label "hints".
        snapshot_before_for_activity => {
          label: %{#{activity.superclass} (anonymous)},
        },
  #@ we may pass Node.data options (keyed by Stack::Captured)
        snapshot_before_for_sub_activity => {
          data: {
            exception_source: true
          }
        }
      }, # node_options
    )

    debugger_nodes = nodes.to_a

    # Nodes#variable_versions
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(debugger_nodes[9].snapshot_before, nodes.to_h[:variable_versions]),
      {:seq=>{:value=>"[:a, :b, :c]", :has_changed=>false}}

    assert_equal debugger_nodes[0].task, activity
    assert_equal debugger_nodes[0].activity, Trailblazer::Activity::TaskWrap.container_activity_for(activity)

    assert_equal debugger_nodes[0].task, activity
    assert_equal debugger_nodes[0].compile_id, nil
    assert_equal debugger_nodes[0].runtime_id, nil
    assert_equal debugger_nodes[0].level, 0
    assert_equal debugger_nodes[0].label, %{Trailblazer::Activity::Railway (anonymous)}
    assert_equal debugger_nodes[0].data, {}
    assert_equal debugger_nodes[0].snapshot_before, stack.to_a[0]
    assert_equal debugger_nodes[0].snapshot_after, stack.to_a[-1]

    assert_equal debugger_nodes[1].activity.class, Trailblazer::Activity # The [activity] field is an Activity.
    assert_equal debugger_nodes[1].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_equal debugger_nodes[1].compile_id, %{Start.default}
    assert_equal debugger_nodes[1].runtime_id, %{Start.default}
    assert_equal debugger_nodes[1].level, 1
    assert_equal debugger_nodes[1].label, %{Start.default}
    assert_equal debugger_nodes[1].data, {}
    assert_equal debugger_nodes[1].snapshot_before, stack.to_a[1]
    assert_equal debugger_nodes[1].snapshot_after, stack.to_a[2]

    assert_equal debugger_nodes[3].task, sub_activity
    # the "parent activity" for {sub_activity} is not the Activity::Railway class but instance of Acivity.
    assert_equal debugger_nodes[3].activity.class, Trailblazer::Activity
    assert_equal debugger_nodes[3].activity, debugger_nodes[1].activity
    assert_equal debugger_nodes[3].data, {exception_source: true}

    assert_equal debugger_nodes[9].compile_id, :d
    assert_equal debugger_nodes[9].runtime_id, "ddddddddd"
    assert_equal debugger_nodes[9].level, 3
    assert_equal debugger_nodes[9].label, %{ddddddddd}
    assert_equal debugger_nodes[9].data, {}
    assert_equal debugger_nodes[9].snapshot_before, stack.to_a[15]
    assert_equal debugger_nodes[9].snapshot_after, stack.to_a[16]
    assert_equal debugger_nodes[9].snapshot_before.data[:ctx_variable_changeset].collect{ |name, _| name }, [:seq] #{:seq=>"[:a, :b, :c]"}
    assert_equal debugger_nodes[9].snapshot_after.data[:ctx_variable_changeset].collect{ |name, _| name }, [:seq] #, {:seq=>"[:a, :b, :c, :d]"}
  end
end
