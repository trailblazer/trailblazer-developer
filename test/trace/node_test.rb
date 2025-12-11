require "test_helper"

class TraceNodeTest < Minitest::Spec
  def inspect_task(task)
    CU.strip(task.inspect)
  end

  def assert_trace_node(node, task:, inspect_task: method(:inspect_task), node_class: Trailblazer::Developer::Trace::Node)
    assert_equal node.class, node_class
    assert_equal inspect_task.(node.snapshot_before.task), task
    if node_class == Trailblazer::Developer::Trace::Node::Incomplete
      assert_nil node.snapshot_after
    else
      assert_equal inspect_task.(node.snapshot_after.task), task
    end
  end

  it do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(
      sub_activity_options: {id: "B"}, _activity_options: {id: "C"})

    ctx, flow_options, signal = kernel.__(
      activity,
      {seq: []},
      **Trailblazer::Developer::Trace.options_for_canonical_invoke
    )

    stack = flow_options[:stack]

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    trace_nodes = Dev::Trace.build_nodes(stack.to_a)

    assert_equal 14, trace_nodes.size

    assert_trace_node trace_nodes[0],  task: CU.strip(activity.inspect)
    assert_trace_node trace_nodes[1],    task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[2],    task: %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>>)
    assert_trace_node trace_nodes[3],    task: CU.strip(sub_activity.inspect)
    assert_trace_node trace_nodes[4],      task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[5],      task: %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>>)
    assert_trace_node trace_nodes[6],      task: CU.strip(_activity.inspect)
    assert_trace_node trace_nodes[7],        task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[8],        task: %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:c>>>)
    assert_trace_node trace_nodes[9],        task: %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:d>>>)
    assert_trace_node trace_nodes[10],       task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_trace_node trace_nodes[11],     task: %{#<Trailblazer::Activity::End semantic=:success>}
    assert_trace_node trace_nodes[12],   task: %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:e>>>)
    assert_trace_node trace_nodes[13],   task: %{#<Trailblazer::Activity::End semantic=:success>}


  #@ ParentMap
    parent_map = Dev::Trace::ParentMap.build(trace_nodes)

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
    assert_equal Dev::Trace::ParentMap.path_for(parent_map, trace_nodes[0]), []
    assert_equal Dev::Trace::ParentMap.path_for(parent_map, trace_nodes[2]), [:a]
    assert_equal Dev::Trace::ParentMap.path_for(parent_map, trace_nodes[3]), ["B"]
    assert_equal Dev::Trace::ParentMap.path_for(parent_map, trace_nodes[5]), ["B", :b]
    assert_equal Dev::Trace::ParentMap.path_for(parent_map, trace_nodes[9]), ["B", "C", :d]

    # this test is to make sure the computed path and {#find_path} play along nicely.
    assert_equal CU.strip(Trailblazer::Developer::Introspect.find_path(activity, ["B", "C", :d])[0].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:d>>>)
  end

  it "{Tree} doesn't choke on identical, nested tasks" do
    sub_activity = nil
      _activity    = nil

    activity = Class.new(Trailblazer::Activity::Railway) do
      MyCallable = Trailblazer::Core::Utils::DefSteps.def_task(:a)
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

    ctx, flow_options, signal = kernel.__(
      activity,
      {seq: []},
      **Trailblazer::Developer::Trace.options_for_canonical_invoke
    )

    stack = flow_options[:stack]

    assert_equal ctx[:seq], [:a, :b, :c, :a, :a, :e]

    trace_nodes = Dev::Trace.build_nodes(stack.to_a)

    inspect_task = ->(task) { [task.name] }

    assert_trace_node trace_nodes[0], task: CU.strip(activity.inspect)
    assert_trace_node trace_nodes[1], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[2], task: [:a], inspect_task: inspect_task
    assert_trace_node trace_nodes[3], task: CU.strip(sub_activity.inspect)
    assert_trace_node trace_nodes[4], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[5], task: %{#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>>}
    assert_trace_node trace_nodes[6], task: CU.strip(_activity.inspect)
    assert_trace_node trace_nodes[7], task: %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[8], task: %{#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:c>>>}
    assert_trace_node trace_nodes[9], task: [:a], inspect_task: inspect_task
    assert_trace_node trace_nodes[10], task: %{#<Trailblazer::Activity::End semantic=:success>}          # _activity.End.success
    assert_trace_node trace_nodes[11], task: [:a], inspect_task: inspect_task
    assert_trace_node trace_nodes[12], task: %{#<Trailblazer::Activity::End semantic=:success>}                   # sub_activity.End.success
    assert_trace_node trace_nodes[13], task: %{#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:e>>>}
    assert_trace_node trace_nodes[14], task: %{#<Trailblazer::Activity::End semantic=:success>}
    # assert_nil trace_nodes[5]
  end

  it "can generate a beautiful tree for incomplete stacks" do
    # TODO: test multiple successive incomplete tasks.
    #            exception style where at some point all ascendants are incomplete.

    ctx = {validate: false, seq: []}

    ctx, flow_options, signal = kernel.__(
      Tracing::ValidateWithRescue,
      {seq: []},
      **Trailblazer::Developer::Trace.options_for_canonical_invoke
    )

    stack = flow_options[:stack]


    trace_nodes = Dev::Trace.build_nodes(stack.to_a)

    assert_equal trace_nodes.size, 7
    assert_trace_node trace_nodes[0], task: Tracing::ValidateWithRescue.inspect
    assert_trace_node trace_nodes[1], task:   %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[2], task:   Tracing::ValidateWithRescue.method(:rescue).inspect
    assert_trace_node trace_nodes[3], task:     %{Tracing::ValidateWithRescue::Validate}, node_class: Trailblazer::Developer::Trace::Node::Incomplete
    assert_trace_node trace_nodes[4], task:       %{#<Trailblazer::Activity::Start semantic=:default>}
    assert_trace_node trace_nodes[5], task:       %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:validate>>>), node_class: Trailblazer::Developer::Trace::Node::Incomplete
    assert_trace_node trace_nodes[6], task:   %{#<Trailblazer::Activity::End semantic=:success>}
    assert_nil trace_nodes[7]
  end
end
