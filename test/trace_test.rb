require "test_helper"

# Test {Trace.call} and {Trace::Present.call}
class TraceTest < Minitest::Spec
  # FIXME: wtf is this test?
  it do
    nested_activity.([{seq: []}])
  end

  it "traces flat activity" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke( bc, [{seq: []}, {flow: true}])

    assert_equal signal.class.inspect, %{Trailblazer::Activity::End}

    assert_equal ctx.inspect, %{{:seq=>[:b, :c]}}
    assert_equal flow_options[:flow].inspect, %{true}

    output = Dev::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    _(output).must_equal %{#<Trailblazer::Activity:>
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "you can pass an explicit task label via {:label}" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(bc, [{seq: []}, {}])

    output = Dev::Trace::Present.(
      stack,
      # options_for_renderer:
      stack.to_a[0] => {label: "#{bc.class} (anonymous)"}
    )

    assert_equal output, %{Trailblazer::Activity (anonymous)
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

# TODO: test label explicitely
    output = Dev::Trace::Present.(stack, stack.to_a[0] => {label: "#{activity.superclass} (anonymous)"})

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

  it "{Present.call} accepts block to produce options that can be merged with original options" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(bc, [{seq: []}, {flow: true}])


    output = Dev::Trace::Present.(stack, stack.to_a[0] => {label: "<Anonymous activity>"}) do |enumerable_tree, **options|

    end

    assert_equal output, %{<Anonymous activity>
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "{Present.call} allows to inject :renderer and pass through additional arguments to the renderer (e.g. {:color})" do
    stack, _ = Dev::Trace.invoke(nested_activity, [{ seq: [] }, {}])

    renderer = ->(debugger_node:, tree:, color:, **) do
      task = debugger_node.captured_node.captured_input.task

      # id_label = label[task] || Trailblazer::Activity::Introspect::Graph(debugger_node.captured_node.captured_input.activity).find { |n| n.task == task }.id
      id_label = debugger_node.label

      if task.is_a? Method
        task = "#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.#{task.name}>"
      end
      [
        debugger_node.level,
        %{#{debugger_node.level}/#{task}/#{debugger_node.captured_node.captured_output.data[:signal]}/#{id_label}/#{color}}
      ]
    end

    output = Dev::Trace::Present.(
      stack,
      renderer: renderer,
      color:    "pink", # additional options.
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
