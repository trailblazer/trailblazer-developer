require "test_helper"

# Test {Trace.call} and {Trace::Present.call}
class TraceTest < Minitest::Spec
  it "traces flat strategy" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(flat_activity, [{seq: []}, {flow: true}])

    assert_equal signal.class.inspect, %{Trailblazer::Activity::End}

    assert_equal ctx.inspect, %{{:seq=>[:B, :C]}}
    assert_equal flow_options[:flow].inspect, %{true}

    output = Dev::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    assert_equal output, %{#<Class:>
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "traces flat activity" do
    activity = flat_activity.to_h[:activity]

    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(activity, [{seq: []}, {flow: true}])

    assert_equal signal.class.inspect, %{Trailblazer::Activity::End}

    assert_equal ctx.inspect, %{{:seq=>[:B, :C]}}
    assert_equal flow_options[:flow].inspect, %{true}

    output = Dev::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    assert_equal output, %{#<Trailblazer::Activity:>
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "you can pass an explicit task label via {:label}" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(flat_activity, [{seq: []}, {}])

    output = Dev::Trace::Present.(
      stack,
      node_options: {
        stack.to_a[0] => {label: "#{flat_activity.class} (anonymous)"}
      }
    )

    assert_equal output, %{Class (anonymous)
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "nested tracing" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(e_options: {Trailblazer::Activity::Railway.Out() => [:nil_value]})

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {flow: true}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

  #@ we get ctx_snapshot for in and out
    assert_equal stack.to_a[3].data[:ctx_snapshot], {:seq=>"[]"}
    assert_equal stack.to_a[4].data[:ctx_snapshot], {:seq=>"[:a]"}

    assert_equal stack.to_a[23].data[:ctx_snapshot], {:seq=>"[:a, :b, :c, :d]"}
  #@ we see out snapshot after Out() filters, {:nil_value} in added in {Out()}
    assert_equal stack.to_a[24].data[:ctx_snapshot], {:seq=>"[:a, :b, :c, :d, :e]", :nil_value=>"nil"}

# TODO: test label explicitely
    output = Dev::Trace::Present.(stack,
      node_options: {
        stack.to_a[0] => {label: "#{activity.superclass} (anonymous)"},
      }
    )

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
    input_collector = ->(wrap_config, ((ctx, _), _)) { { ctx: ctx, something: :else } }
    output_collector = ->(wrap_config, ((ctx, _), _)) { { ctx: ctx, signal: wrap_config[:return_signal] } }

    stack, signal, (ctx, _) = Dev::Trace.invoke(
      flat_activity,
      [
        { seq: [] },
        {
          input_data_collector: input_collector,
          output_data_collector: output_collector,
        }
      ]
    )

    assert_equal ctx[:seq], [:B, :C]

    captured_input  = stack.to_a[0]
    captured_output = stack.to_a[-1]

    assert_equal captured_input.data, { ctx: { seq: [:B, :C] }, something: :else }
    assert_equal captured_output.data, { ctx: { seq: [:B, :C] }, signal: signal }
  end

  it "{Present.call} accepts block to produce options that can be merged with original options" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(flat_activity, [{seq: []}, {flow: true}])


    output = Dev::Trace::Present.(stack,
      node_options: {
        stack.to_a[0] => {label: "<Anonymous activity>"}
      }
    )

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

    _(output).must_equal %{0/#<Class:>/#<Trailblazer::Activity::End semantic=:success>/#<Class:>/pink
|-- 1/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
|-- 1/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.b>/Trailblazer::Activity::Right/B/pink
|-- 1/#<Class:>/#<Trailblazer::Activity::End semantic=:success>/D/pink
|   |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Trailblazer::Activity::Right/Start.default/pink
|   |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.B>/Trailblazer::Activity::Right/B/pink
|   |-- 2/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.C>/Trailblazer::Activity::Right/C/pink
|   `-- 2/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
|-- 1/#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.e>/Trailblazer::Activity::Right/E/pink
`-- 1/#<Trailblazer::Activity::End semantic=:success>/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end
end
