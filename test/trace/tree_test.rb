require "test_helper"

class TraceTreeTest < Minitest::Spec
  def inspect_task(task)
    task.inspect
  end

  def assert_tree_node(node, task:, inspect_task: method(:inspect_task))
    assert_equal inspect_task.(node.snapshot_before.task), task
    assert_equal inspect_task.(node.snapshot_after.task), task
  end

  it do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(
      sub_activity_options: {id: "B"}, _activity_options: {id: "C"})

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    trace_nodes = Dev::Trace.Tree(stack.to_a)

    assert_equal 14, trace_nodes.size

    assert_tree_node trace_nodes[0],  task: activity.inspect
    assert_tree_node trace_nodes[1],    task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[2],    task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
    assert_tree_node trace_nodes[3],    task: sub_activity.inspect
    assert_tree_node trace_nodes[4],      task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[5],      task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
    assert_tree_node trace_nodes[6],      task: _activity.inspect
    assert_tree_node trace_nodes[7],        task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[8],        task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
    assert_tree_node trace_nodes[9],        task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
    assert_tree_node trace_nodes[10],       task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_tree_node trace_nodes[11],     task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_tree_node trace_nodes[12],   task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
    assert_tree_node trace_nodes[13],   task: %{#<Trailblazer::Activity::End semantic=:success>}


  #@ ParentMap
    parent_map = Dev::Trace::Tree::ParentMap.build(trace_nodes)

    assert_equal parent_map[trace_nodes[0]], nil
    assert_equal parent_map[trace_nodes[1]], trace_nodes[0]
    assert_equal parent_map[trace_nodes[2]], trace_nodes[0] # :a
    assert_equal parent_map[trace_nodes[3]], trace_nodes[0]
    assert_equal parent_map[trace_nodes[4]], trace_nodes[3]
    assert_equal parent_map[trace_nodes[5]], trace_nodes[3]
    assert_equal parent_map[trace_nodes[6]], trace_nodes[3]
    assert_equal parent_map[trace_nodes[7]], trace_nodes[6]
    assert_equal parent_map[trace_nodes[8]], trace_nodes[6]
    assert_equal parent_map[trace_nodes[9]], trace_nodes[6]
    assert_equal parent_map[trace_nodes[10]], trace_nodes[6]
    assert_equal parent_map[trace_nodes[11]], trace_nodes[3]
    assert_equal parent_map[trace_nodes[12]], trace_nodes[0]
    assert_equal parent_map[trace_nodes[13]], trace_nodes[0]

    assert_equal parent_map[trace_nodes[15]], nil

  #@ Tree::ParentMap.path_for()
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, trace_nodes[0]), []
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, trace_nodes[2]), [:a]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, trace_nodes[3]), ["B"]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, trace_nodes[5]), ["B", :b]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, trace_nodes[9]), ["B", "C", :d]

    # this test is to make sure the computed path and {#find_path} play along nicely.
    assert_equal Trailblazer::Developer::Introspect.find_path(activity, ["B", "C", :d])[0].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
  end

  it "{Tree} doesn't choke on identical, nested tasks" do
    sub_activity = nil
      _activity    = nil

    activity = Class.new(Trailblazer::Activity::Railway) do
      MyCallable = T.def_task(:a)
      include T.def_steps(:e)

      sub_activity = Class.new(Trailblazer::Activity::Railway) do
        include T.def_steps(:b)
        _activity = Class.new(Trailblazer::Activity::Railway) do
          include T.def_steps(:c)
          step :c
          step task: MyCallable
        end

        step :b
        step Subprocess(_activity)
        step task: MyCallable
      end
      step task: MyCallable
      step Subprocess(sub_activity)
      step :e
    end

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :a, :a, :e]

    trace_nodes = Dev::Trace.Tree(stack.to_a)

    inspect_task = ->(task) { [task.name] }

    assert_tree_node trace_nodes[0], task: activity.inspect
    assert_tree_node trace_nodes[1], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[2], task: [:a], inspect_task: inspect_task
    assert_tree_node trace_nodes[3], task: sub_activity.inspect
    assert_tree_node trace_nodes[4], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[5], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
    assert_tree_node trace_nodes[6], task: _activity.inspect
    assert_tree_node trace_nodes[7], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node trace_nodes[8], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
    assert_tree_node trace_nodes[9], task: [:a], inspect_task: inspect_task
    assert_tree_node trace_nodes[10], task: %{#<Trailblazer::Activity::End semantic=:success>}          # _activity.End.success
    assert_tree_node trace_nodes[11], task: [:a], inspect_task: inspect_task
    assert_tree_node trace_nodes[12], task: %{#<Trailblazer::Activity::End semantic=:success>}                   # sub_activity.End.success
    assert_tree_node trace_nodes[13], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
    assert_tree_node trace_nodes[14], task: %{#<Trailblazer::Activity::End semantic=:success>}
    # assert_nil trace_nodes[5]
  end
end
