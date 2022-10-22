require "test_helper"

class TraceTreeTest < Minitest::Spec
  def assert_tree_node(node, task:)
    assert_equal node.captured_input.task.inspect, task
    assert_equal node.captured_output.task.inspect, task
  end

  it do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity

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
    parent_map = Dev::Trace::Tree::ParentMap.for(tree)

    parent_map = parent_map.to_h

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
    assert_equal Dev::Trace::Tree.Enumerable(tree).count, 14


    traversed_nodes = Dev::Trace::Tree.Enumerable(tree).collect do |n| n end


    assert_equal traversed_nodes.count, 14

    # raise traversed_nodes[1].captured_input.inspect

    assert_equal traversed_nodes[0], tree                             # activity
    assert_equal traversed_nodes[1], tree.nodes[0]                    #   Start
    assert_equal traversed_nodes[2], tree.nodes[1]                    #   a
    assert_equal traversed_nodes[3], tree.nodes[2]                    #   sub_activity
    assert_equal traversed_nodes[4], tree.nodes[2].nodes[0]           #     Start
    assert_equal traversed_nodes[5], tree.nodes[2].nodes[1]           #     b
    assert_equal traversed_nodes[6], tree.nodes[2].nodes[2]           #     _activity
    assert_equal traversed_nodes[7], tree.nodes[2].nodes[2].nodes[0]  #     Start
    assert_equal traversed_nodes[8], tree.nodes[2].nodes[2].nodes[1]  #     c
    assert_equal traversed_nodes[9], tree.nodes[2].nodes[2].nodes[2]  #     d
    assert_equal traversed_nodes[10], tree.nodes[2].nodes[2].nodes[3] #     End
    assert_equal traversed_nodes[11], tree.nodes[2].nodes[3]          #   End
    assert_equal traversed_nodes[12], tree.nodes[3]                   #   e
    assert_equal traversed_nodes[13], tree.nodes[4]                   #   End
    assert_equal traversed_nodes[14], tree.nodes[5]                   # End
  end
end
