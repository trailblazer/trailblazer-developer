require "test_helper"

# Test {Trace::Present.call}
class TracePresentTest < Minitest::Spec
   it "accepts block to produce options that are merged with internal options" do
    stack, signal, (ctx, flow_options), _ = Dev::Trace.invoke(flat_activity, [{seq: []}, {flow: true}])


    output = Dev::Trace::Present.(stack) do |trace_nodes:, **|
      {
        node_options: {
          trace_nodes[0] => {label: "<Anonymous activity>"}
        }
      }
    end

    assert_equal output, %{<Anonymous activity>
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "deprecates {:node_options}" do
    stack, _ = Dev::Trace.invoke(flat_activity, [{seq: []}, {}])

    exception = assert_raises do
      output = Dev::Trace::Present.(
        stack,
        node_options: {
          stack.to_a[0] => {label: "#{flat_activity.class} (anonymous)"}
        }
      )
    end

    assert_equal exception.message, %([Trailblazer] The `:node_options` option for `Trace::Present` is deprecated. Please use the block style as described here: #FIXME)
  end

  it "accepts {:render_method}" do
    stack, _ = Dev::Trace.invoke(nested_activity, [{seq: []}, {}])

    my_render_method = ->(debugger_trace:, **options) do
      [
        debugger_trace.to_a.size,
        options.keys
      ]
    end

    output = Dev::Trace::Present.(
      stack,
      render_method: my_render_method,
      color:    "pink", # additional options.
    )

    assert_equal output, [10, [:node_options, :color]]
  end

  it "accepts {:renderer} and pass through additional arguments to the renderer (e.g. {:color})" do
    stack, _ = Dev::Trace.invoke(nested_activity, [{ seq: [] }, {}])

    renderer = ->(debugger_node:, debugger_trace:, color:, **) do
      task = debugger_node.trace_node.snapshot_before.task

      id_label = debugger_node.label

      if task.is_a? Method
        task = "#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.#{task.name}>"
      end
      [
        debugger_node.level,
        %{#{debugger_node.level}/#{task}/#{debugger_node.trace_node.snapshot_after.data[:signal]}/#{id_label}/#{color}}
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
