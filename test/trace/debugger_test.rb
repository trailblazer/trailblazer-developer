require "test_helper"

class DebuggerTest < Minitest::Spec
  it "what" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(
      sub_activity_options: {id: "B"}, _activity_options: {id: "C"})

    # We want to change the Railway[:activity] field, which is the {Activity} instance seen at runtime.
    _activity.to_h[:activity].instance_variable_set(:@special, true) # FIXME: don't kill me for this horrible flag.


    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{seq: []}, {}])

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    my_compute_runtime_id = ->(captured_node:, activity:, compile_id:, **) do
      return compile_id unless activity.instance_variable_get(:@special)

      compile_id.to_s*9
    end


    tree, processed = Dev::Trace.Tree(stack.to_a)

    enumerable_tree = Dev::Trace::Tree.Enumerable(tree)

    debugger_nodes = Dev::Trace::Debugger::Node.build(
      tree,
      enumerable_tree,

      compute_runtime_id: my_compute_runtime_id
    )

    assert_equal debugger_nodes[0].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_equal debugger_nodes[0].compile_id, %{Start.default}
    assert_equal debugger_nodes[0].compile_path, ["Start.default"]
    assert_equal debugger_nodes[0].runtime_id, %{Start.default}


    assert_equal debugger_nodes[8].compile_id, :d
    assert_equal debugger_nodes[8].compile_path, ["B", "C", :d]
    assert_equal debugger_nodes[8].runtime_id, "ddddddddd"
    assert_equal debugger_nodes[8].runtime_path, ["B", "C", "ddddddddd"]
  end
end
