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


    tree, processed = Dev::Trace.Tree(stack.to_a)

    assert_tree_node tree, task: activity.inspect
    assert_tree_node tree.nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[1], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
    assert_tree_node tree.nodes[2], task: sub_activity.inspect
    assert_tree_node tree.nodes[2].nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[2].nodes[1], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
    assert_tree_node tree.nodes[2].nodes[2], task: _activity.inspect
    assert_tree_node tree.nodes[2].nodes[2].nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[2].nodes[2].nodes[1], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
    assert_tree_node tree.nodes[2].nodes[2].nodes[2], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
    assert_tree_node tree.nodes[2].nodes[2].nodes[3], task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_tree_node tree.nodes[2].nodes[3], task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_tree_node tree.nodes[3], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
    assert_tree_node tree.nodes[4], task: %{#<Trailblazer::Activity::End semantic=:success>}


  #@ ParentMap
    parent_map = Dev::Trace::Tree::ParentMap.build(tree)

    parent_map = parent_map.to_h # FIXME.

    assert_equal parent_map[tree], nil
    assert_equal parent_map[tree.nodes[0]], tree
    assert_equal parent_map[tree.nodes[1]], tree
    assert_equal parent_map[tree.nodes[2]], tree
    assert_equal parent_map[tree.nodes[2].nodes[0]], tree.nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[1]], tree.nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[2]], tree.nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[2].nodes[0]], tree.nodes[2].nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[2].nodes[1]], tree.nodes[2].nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[2].nodes[2]], tree.nodes[2].nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[2].nodes[3]], tree.nodes[2].nodes[2]
    assert_equal parent_map[tree.nodes[2].nodes[3]], tree.nodes[2]
    assert_equal parent_map[tree.nodes[3]], tree
    assert_equal parent_map[tree.nodes[4]], tree
    assert_equal parent_map[tree.nodes[5]], nil


  #@ Tree::Enumerable
    array_of_nodes = Dev::Trace::Tree.Enumerable(tree)
    assert_equal array_of_nodes.count, 14


    assert_equal array_of_nodes.count, 14
    assert_equal array_of_nodes.collect { |n| n.class }.uniq, [Trailblazer::Developer::Trace::Tree::Node]

    # raise array_of_nodes[1].snapshot_before.inspect

    assert_equal array_of_nodes[0], tree                             # activity
    assert_equal array_of_nodes[1], tree.nodes[0]                    #   Start
    assert_equal array_of_nodes[2], tree.nodes[1]                    #   a
    assert_equal array_of_nodes[3], tree.nodes[2]                    #   sub_activity
    assert_equal array_of_nodes[4], tree.nodes[2].nodes[0]           #     Start
    assert_equal array_of_nodes[5], tree.nodes[2].nodes[1]           #     b
    assert_equal array_of_nodes[6], tree.nodes[2].nodes[2]           #     _activity
    assert_equal array_of_nodes[7], tree.nodes[2].nodes[2].nodes[0]  #       Start
    assert_equal array_of_nodes[8], tree.nodes[2].nodes[2].nodes[1]  #       c
    assert_equal array_of_nodes[9], tree.nodes[2].nodes[2].nodes[2]  #       d
    assert_equal array_of_nodes[10], tree.nodes[2].nodes[2].nodes[3] #     End
    assert_equal array_of_nodes[11], tree.nodes[2].nodes[3]          #   End
    assert_equal array_of_nodes[12], tree.nodes[3]                   #   e
    assert_equal array_of_nodes[13], tree.nodes[4]                   #   End
    assert_equal array_of_nodes[14], tree.nodes[5]                   # End

  #@ Tree::ParentMap.path_for()
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, array_of_nodes[0]), []
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, array_of_nodes[2]), [:a]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, array_of_nodes[3]), ["B"]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, array_of_nodes[5]), ["B", :b]
    assert_equal Dev::Trace::Tree::ParentMap.path_for(parent_map, array_of_nodes[9]), ["B", "C", :d]

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

    tree, processed = Dev::Trace.Tree(stack.to_a)

    inspect_task = ->(task) { [task.name] }

    assert_tree_node tree, task: activity.inspect
    assert_tree_node tree.nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[1], task: [:a], inspect_task: inspect_task
    assert_tree_node tree.nodes[2], task: sub_activity.inspect
    assert_tree_node tree.nodes[2].nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[2].nodes[1], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
    assert_tree_node tree.nodes[2].nodes[2], task: _activity.inspect
    assert_tree_node tree.nodes[2].nodes[2].nodes[0], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_tree_node tree.nodes[2].nodes[2].nodes[1], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
    assert_tree_node tree.nodes[2].nodes[2].nodes[2], task: [:a], inspect_task: inspect_task
    assert_tree_node tree.nodes[2].nodes[2].nodes[3], task: %{#<Trailblazer::Activity::End semantic=:success>}          # _activity.End.success
    assert_tree_node tree.nodes[2].nodes[3], task: [:a], inspect_task: inspect_task
    assert_tree_node tree.nodes[2].nodes[4], task: %{#<Trailblazer::Activity::End semantic=:success>}                   # sub_activity.End.success
    assert_tree_node tree.nodes[3], task: %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
    assert_tree_node tree.nodes[4], task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_nil tree.nodes[5]
  end
end
