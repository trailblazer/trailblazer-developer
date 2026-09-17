require "test_helper"

class TraceWtfTest < Minitest::Spec
  it "rescues from an exception and colorizes the trace" do
    my_abc_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b
      step :c

      include T.def_steps(:a, :c)

      def b(ctx, seq:, raise_from_b: false, **)
        raise if raise_from_b

        seq << :b
      end
    end

    my_abc_activity_node = Trailblazer::Circuit::Node[my_abc_activity, Trailblazer::Circuit::Processor]

    # my_abc_activity_node.task.instance_variable_set(:@pipe, true) # FIXME: this is used in WrapRuntime::Runner.
    my_canonical_Create_tw_node = Trailblazer::Circuit::Node[
      Trailblazer::Circuit::Builder.Pipeline(
        [:"task_wrap.call_task", node: my_abc_activity_node]
      ),
      Trailblazer::Circuit::Processor
    ]

    my_wtf_circuit_fixme = Trailblazer::Circuit::Builder.Pipeline(
      [:wtf_top_canonical, node: my_canonical_Create_tw_node]
    )
    my_wtf_node = Trailblazer::Developer::Wtf::Node[my_wtf_circuit_fixme, Trailblazer::Circuit::Processor]

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_extension_builder = Trailblazer::Circuit::WrapRuntime.Extension(adds: Trailblazer::Developer::Trace::Extension) # WrapRuntime::Extension means we adds

    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
        my_tracing_extension_builder,
      ]
    )

    flow_options = {
      stack:              Trailblazer::Developer::Trace::Stack.new,
      value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
    }

    runner = Trailblazer::Circuit::WrapRuntime::Runner

    output, _ = capture_io do
      assert_raises RuntimeError do # FIXME: use our own error to test we're raising it.
        lib_ctx, flow_options, signal = runner.(
          {target_ctx: {seq: [], raise_from_b: true}},
          flow_options,
          nil,
          runner: runner,
          wrap_runtime: Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions),
          context_implementation: Trailblazer::Circuit::Context,
          id: :Create,
          node: my_wtf_node,
        )
      end
    end

    # assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    # assert_equal signal.to_h[:semantic], :success

puts output
assert_equal output,
"\e[37m...Create\e[0m
`-- \e[37m...wtf_top_canonical\e[0m
    `-- \e[37m...task_wrap.call_task\e[0m
        |-- \e[32m...a\e[0m
        |   `-- \e[32m...task_wrap.call_task\e[0m
        |       |-- \e[30m...invoke_provider\e[0m
        |       |-- \e[30m...is_signal?\e[0m
        |       `-- \e[32m...compute_binary_signal\e[0m
        `-- \e[37m...b\e[0m
            `-- \e[37m...task_wrap.call_task\e[0m
                `-- \e[31m\e[1m...invoke_provider\e[0m
"
  end

  it "what" do
    raise "allow correct coloring for nested activities "
  end
end
