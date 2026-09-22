require "test_helper"

class TraceWtfTest < Minitest::Spec
  let(:my_abc_activity) do
    Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b
      step :c

      include T.def_steps(:a, :c)

      def b(ctx, seq:, raise_from_b: false, **)
        raise if raise_from_b

        seq << :b
      end
    end
  end

  it "rescues from an exception and colorizes the trace" do
    my_abc_activity_node = Trailblazer::Circuit::Node[my_abc_activity, Trailblazer::Circuit::Processor]

    # my_abc_activity_node.task.instance_variable_set(:@pipe, true) # FIXME: this is used in WrapRuntime::Runner.
    my_canonical_Create_tw_node = Trailblazer::Circuit::Node[
      Trailblazer::Circuit::Builder.Pipeline(
        [:"task_wrap.call_task", node: my_abc_activity_node]
      ),
      Trailblazer::Circuit::Processor
    ]

    # mimicking the Invoke pipe here.
    # I decided to leave this test and its prototypical nature to remind us how things work internally.
    _, flow_options, circuit_options = Trailblazer::Developer::Trace::Invoke.add_options_for_trace({}, {}, {extensions: [], node: my_canonical_Create_tw_node})
    _, flow_options, circuit_options = Trailblazer::Activity::Invoke.produce_wrap_runtime({}, flow_options, circuit_options)
    _, flow_options, circuit_options = Trailblazer::Developer::Wtf::Invoke.produce_wtf_node({}, flow_options, circuit_options)

    runner = Trailblazer::Circuit::WrapRuntime::Runner

    output, _ = capture_io do
      assert_raises RuntimeError do # FIXME: use our own error to test we're raising it.
        lib_ctx, flow_options, signal = runner.(
          {target_ctx: {seq: [], raise_from_b: true}},
          flow_options,
          nil,
          runner: runner,
          **circuit_options,
          context_implementation: Trailblazer::Circuit::Context,
          id: :Create,
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

  describe "Developer.wtf?" do
    let(:my_compiler) do
      # DISCUSS: this should be done by trailblazer-rails.
      Trailblazer::Circuit::Adds.(
        Trailblazer::Activity::Invoke::Args::Compiler,
        [:my_trace, Trailblazer::Circuit::Node[Trailblazer::Developer::Trace::Invoke.method(:add_options_for_trace), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
        [:my_wtf, Trailblazer::Circuit::Node[Trailblazer::Developer::Wtf::Invoke.method(:produce_wtf_node), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
      )
    end

    it "provides the Developer.wtf? method that uses the canonical debug pipe" do
      output, _ = capture_io do
        assert_raises RuntimeError do # FIXME: use our own error to test we're raising it.
          Trailblazer::Developer.wtf?(my_abc_activity, {seq: [], raise_from_b: true}, id: :Create, compiler: my_compiler)
        end
      end

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

    it "returns the circuit interface return set" do
      output, _ = capture_io do
        lib_ctx, flow_options, signal = Trailblazer::Developer.wtf?(my_abc_activity, {seq: []}, id: :Create, compiler: my_compiler)

        assert_equal lib_ctx, {target_ctx: {seq: [:a, :b, :c]}}
      end

      puts output
      assert_equal output, %(\e[37m...Create\e[0m
`-- \e[30m...wtf_top_canonical\e[0m
    `-- \e[30m...task_wrap.call_task\e[0m
        |-- \e[32m...a\e[0m
        |   `-- \e[32m...task_wrap.call_task\e[0m
        |       |-- \e[30m...invoke_provider\e[0m
        |       |-- \e[30m...is_signal?\e[0m
        |       `-- \e[32m...compute_binary_signal\e[0m
        |-- \e[32m...b\e[0m
        |   `-- \e[32m...task_wrap.call_task\e[0m
        |       |-- \e[30m...invoke_provider\e[0m
        |       |-- \e[30m...is_signal?\e[0m
        |       `-- \e[32m...compute_binary_signal\e[0m
        |-- \e[32m...c\e[0m
        |   `-- \e[32m...task_wrap.call_task\e[0m
        |       |-- \e[30m...invoke_provider\e[0m
        |       |-- \e[30m...is_signal?\e[0m
        |       `-- \e[32m...compute_binary_signal\e[0m
        `-- \e[30m...End.success\e[0m
            `-- \e[30m...task_wrap.call_task\e[0m
)
    end
  end
end
