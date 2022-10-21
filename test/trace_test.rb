require "test_helper"

# TODO: test A in A in A, traced

class TraceTest < Minitest::Spec
  it do
    nested_activity.([{seq: []}])
  end

  require "trailblazer/developer/trace/tree"
  it "traces flat activity" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(
      bc,
      [
        {seq: []},
        {flow: true, _stack: Dev::Trace::Stack_.new}
      ]
    )

    stack = flow_options[:_stack]


    tree, processed = Dev::Trace.Tree(stack.to_a)

    # raise processed.inspect

    puts "\ntree"
    # pp tree
    # tree = tree
    # puts tree.captured_output.inspect
    # puts tree.nodes[].captured_output.inspect


    # pp Dev::Trace::Tree(stack.to_a)
    assert_equal signal.class.inspect, %{Trailblazer::Activity::End}

    _(ctx.inspect).must_equal %{{:seq=>[:b, :c]}}
    _(flow_options[:flow].inspect).must_equal %{true}

    output = Dev::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- C
    `-- End.success}
  end

  it "allows nested tracing" do
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
        step Subprocess(_activity)
      end

      step :a
      step Subprocess(sub_activity)
      step :e
    end


    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {flow: true, _stack: Dev::Trace::Stack_.new}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    stack = flow_options[:_stack]
# FIXME: stack test
    stack_ary = stack.to_a

    # top activity
    assert_equal stack_ary[0].class, Trailblazer::Developer::Trace::Entity::Input
    assert_equal stack_ary[0].task, activity
      assert_equal stack_ary[1].class, Trailblazer::Developer::Trace::Entity::Input
      assert_equal stack_ary[1].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
      assert_equal stack_ary[2].class, Trailblazer::Developer::Trace::Entity::Output
      assert_equal stack_ary[2].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}

      assert_equal stack_ary[3].class, Trailblazer::Developer::Trace::Entity::Input
      assert_equal stack_ary[3].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
      assert_equal stack_ary[4].class, Trailblazer::Developer::Trace::Entity::Output
      assert_equal stack_ary[4].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}

      # sub_activity
      assert_equal stack_ary[5].class, Trailblazer::Developer::Trace::Entity::Input
      assert_equal stack_ary[5].task, sub_activity
        assert_equal stack_ary[6].class, Trailblazer::Developer::Trace::Entity::Input
        assert_equal stack_ary[6].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_equal stack_ary[7].class, Trailblazer::Developer::Trace::Entity::Output
        assert_equal stack_ary[7].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}

        assert_equal stack_ary[8].class, Trailblazer::Developer::Trace::Entity::Input
        assert_equal stack_ary[8].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
        assert_equal stack_ary[9].class, Trailblazer::Developer::Trace::Entity::Output
        assert_equal stack_ary[9].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}

        # _activity
        assert_equal stack_ary[10].class, Trailblazer::Developer::Trace::Entity::Input
        assert_equal stack_ary[10].task, _activity
          assert_equal stack_ary[11].class, Trailblazer::Developer::Trace::Entity::Input
          assert_equal stack_ary[11].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
          assert_equal stack_ary[12].class, Trailblazer::Developer::Trace::Entity::Output
          assert_equal stack_ary[12].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}

          assert_equal stack_ary[13].class, Trailblazer::Developer::Trace::Entity::Input
          assert_equal stack_ary[13].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
          assert_equal stack_ary[14].class, Trailblazer::Developer::Trace::Entity::Output
          assert_equal stack_ary[14].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}

          assert_equal stack_ary[15].class, Trailblazer::Developer::Trace::Entity::Input
          assert_equal stack_ary[15].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
          assert_equal stack_ary[16].class, Trailblazer::Developer::Trace::Entity::Output
          assert_equal stack_ary[16].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}

          assert_equal stack_ary[17].class, Trailblazer::Developer::Trace::Entity::Input
          assert_equal stack_ary[17].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
          assert_equal stack_ary[18].class, Trailblazer::Developer::Trace::Entity::Output
          assert_equal stack_ary[18].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}

        assert_equal stack_ary[19].class, Trailblazer::Developer::Trace::Entity::Output
        assert_equal stack_ary[19].task, _activity

        assert_equal stack_ary[20].class, Trailblazer::Developer::Trace::Entity::Input
        assert_equal stack_ary[20].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
        assert_equal stack_ary[21].class, Trailblazer::Developer::Trace::Entity::Output
        assert_equal stack_ary[21].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}

      assert_equal stack_ary[22].class, Trailblazer::Developer::Trace::Entity::Output
      assert_equal stack_ary[22].task, sub_activity

      assert_equal stack_ary[23].class, Trailblazer::Developer::Trace::Entity::Input
      assert_equal stack_ary[23].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
      assert_equal stack_ary[24].class, Trailblazer::Developer::Trace::Entity::Output
      assert_equal stack_ary[24].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}

      assert_equal stack_ary[25].class, Trailblazer::Developer::Trace::Entity::Input
      assert_equal stack_ary[25].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal stack_ary[26].class, Trailblazer::Developer::Trace::Entity::Output
      assert_equal stack_ary[26].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}

    assert_equal stack_ary[27].class, Trailblazer::Developer::Trace::Entity::Output
    assert_equal stack_ary[27].task, activity

    assert_equal stack.to_a.size, 28

# FIXME: Tree-test
    tree, processed = Dev::Trace.Tree(stack.to_a)
    assert_equal tree.captured_input.task, activity



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

    # puts "@@@@@ #{.inspect}"


    assert_equal Dev::Trace::Tree.Enumerable(tree).count, 14


    traversed_nodes = Dev::Trace::Tree.Enumerable(tree).collect do |n| n end

    traversed_nodes.each do |n|
      puts "@@@@@ #{n.captured_input.activity.inspect}"
      # pp n.captured_input.data
      # raise
      # puts n.captured_input.task
    end

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








    output = Dev::Trace::Present.(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- D
    |   |-- Start.default
    |   |-- B
    |   |-- C
    |   `-- End.success
    |-- E
    `-- End.success}
  end

  it "collects stack entity data from :data collector" do
    stack, signal, * = Dev::Trace.invoke(bc, [ { seq: [] } ])

    nested = stack.to_a.first

    _(nested.first.data).must_equal({ ctx: { seq: [:b, :c] }, task_name: bc })
    _(nested.last.data).must_equal({ ctx: { seq: [:b, :c] }, signal: signal })
  end

  it "allows to inject custom :data collector" do
    input_collector = ->(wrap_config, (ctx, _), _) { { ctx: ctx, something: :else } }
    ouput_collector = ->(wrap_config, (ctx, _), _) { { ctx: ctx, signal: wrap_config[:return_signal] } }

    stack, signal, * = Dev::Trace.invoke(
      bc,
      [
        { seq: [] },
        {
          input_data_collector: input_collector,
          output_data_collector: ouput_collector,
        }
      ]
    )

    nested = stack.to_a.first
    _(nested.first.data).must_equal({ ctx: { seq: [:b, :c] }, something: :else })
    _(nested.last.data).must_equal({ ctx: { seq: [:b, :c] }, signal: signal })
  end

  it "Present allows to inject :renderer and pass through additional arguments to the renderer" do
    stack, _ = Dev::Trace.invoke( nested_activity,
      [
        { seq: [] },
        {}
      ]
    )

    renderer = ->(task_node:, position:, tree:) do
      assert_equal tree[position], task_node
      task = task_node.input.task
      if task.is_a? Method
        task = "#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.#{task.name}>"
      end
      [
        task_node.level,
        %{#{task_node.level}/#{task}/#{task_node.output.data[:signal]}/#{task_node.value}/#{task_node.color}}
      ]
    end

    output = Dev::Trace::Present.(stack, renderer: renderer,
      color: "pink" # additional options.
    )

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{`-- 1/#<Trailblazer::Activity:>/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity:>/pink
    |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
    |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.b>/Trailblazer::Activity::Right/B/pink
    |-- 2/#<Trailblazer::Activity:>/#<Trailblazer::Activity::End semantic=:success>/D/pink
    |   |-- 3/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
    |   |-- 3/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.b>/Trailblazer::Activity::Right/B/pink
    |   |-- 3/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.c>/Trailblazer::Activity::Right/C/pink
    |   `-- 3/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
    |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.f>/Trailblazer::Activity::Right/E/pink
    `-- 2/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end

  it "allows to inject custom :stack" do
    skip "this test goes to the developer gem"
    stack = Dev::Trace::Stack.new

    begin
      returned_stack, _ = Dev::Trace.invoke( nested_activity,
        [
          { content: "Let's start writing" },
          { stack: stack }
        ]
      )
    rescue
      # pp stack
      puts Dev::Trace::Present.(stack)
    end

    _(returned_stack).must_equal stack
  end
end
