require "test_helper"

# TODO: test A in A in A, traced

class TraceTest < Minitest::Spec
  # FIXME: wtf is this test?
  it do
    nested_activity.([{seq: []}])
  end


  it "traces flat activity" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(
      bc,
      [
        {seq: []},
        {flow: true}
      ]
    )

    assert_equal signal.class.inspect, %{Trailblazer::Activity::End}

    assert_equal ctx.inspect, %{{:seq=>[:b, :c]}}
    assert_equal flow_options[:flow].inspect, %{true}

    output = Dev::Trace::Present.(stack, label: {bc => bc.inspect})
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{#<Trailblazer::Activity:>
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

    output = Dev::Trace::Present.(stack, label: {activity => "#{activity.superclass} (anonymous)"})

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

  it "allows to inject custom :data_collector" do
    input_collector = ->(wrap_config, (ctx, _), _) { { ctx: ctx, something: :else } }
    output_collector = ->(wrap_config, (ctx, _), _) { { ctx: ctx, signal: wrap_config[:return_signal] } }

    stack, signal, (ctx, _) = Dev::Trace.invoke(
      bc,
      [
        { seq: [] },
        {
          input_data_collector: input_collector,
          output_data_collector: output_collector,
        }
      ]
    )

    assert_equal ctx[:seq], [:b, :c]

    captured_input  = stack.to_a[0]
    captured_output = stack.to_a[-1]

    assert_equal captured_input.data, { ctx: { seq: [:b, :c] }, something: :else }
    assert_equal captured_output.data, { ctx: { seq: [:b, :c] }, signal: signal }
  end

  it "Present allows to inject :renderer and pass through additional arguments to the renderer (e.g. {:color})" do
    stack, _ = Dev::Trace.invoke(nested_activity, [{ seq: [] }, {}])

    renderer = ->(task_node:, tree:, color:, label:, **) do
      task = task_node.captured_input.task

      id_label = label[task] || Trailblazer::Activity::Introspect::Graph(task_node.captured_input.activity).find { |n| n.task == task }.id

      if task.is_a? Method
        task = "#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.#{task.name}>"
      end
      [
        task_node.level,
        %{#{task_node.level}/#{task}/#{task_node.captured_output.data[:signal]}/#{id_label}/#{color}}
      ]
    end

    output = Dev::Trace::Present.(
      stack,
      renderer: renderer,
      color:    "pink", # additional options.
      label: {nested_activity => nested_activity.inspect}
    )

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{0/#<Trailblazer::Activity:>/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity:>/pink
|-- 1/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
|-- 1/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.b>/Trailblazer::Activity::Right/B/pink
|-- 1/#<Trailblazer::Activity:>/#<Trailblazer::Activity::End semantic=:success>/D/pink
|   |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
|   |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.b>/Trailblazer::Activity::Right/B/pink
|   |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.c>/Trailblazer::Activity::Right/C/pink
|   `-- 2/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
|-- 1/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.f>/Trailblazer::Activity::Right/E/pink
`-- 1/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end
end
