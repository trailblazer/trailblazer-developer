require "test_helper"

# TODO: test A in A in A, traced

class TraceTest < Minitest::Spec




  it do
    nested_activity.([{seq: []}])
  end


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

  it "nested tracing" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {flow: true}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    output = Dev::Trace::Present.(stack, options_for_renderer: {label: {activity => "#{activity.superclass} (anonymous)"}})

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{Trailblazer::Activity::Railway (anonymous)
|-- Start.default
|-- a
|-- #<Class:>
|   |-- Start.default
|   |-- b
|   |-- #<Class:>
|   |   |-- Start.default
|   |   |-- c
|   |   |-- d
|   |   `-- End.success
|   `-- End.success
|-- e
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
