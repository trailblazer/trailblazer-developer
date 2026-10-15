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

    my_canonical_Create_tw_node = Trailblazer::Circuit::Node[
      Trailblazer::Circuit::Builder.Pipeline(
        [:"task_wrap.call_task", node: my_abc_activity_node]
      ),
      Trailblazer::Circuit::Processor
    ]

    # mimicking the Invoke pipe here.
    # I decided to leave this test and its prototypical nature to remind us how things work internally.

    _, flow_options, circuit_options = Trailblazer::Developer::Trace::Invoke.add_options_for_trace({}, {}, {extensions: [], node: my_canonical_Create_tw_node, conditions: []})
    _, flow_options, circuit_options = Trailblazer::Developer::Trace::Invoke.add_extension_for_wrap_node_tracing(nil, flow_options, circuit_options) # normally, this'd happen in the Invoke pipeline.
    _, flow_options, circuit_options = Trailblazer::Developer::Wtf::Invoke.add_flow_options({}, flow_options, circuit_options)
    _, flow_options, circuit_options = Trailblazer::Developer::Wtf::Invoke.produce_wtf_node({}, flow_options, circuit_options.merge(id: :Create))
    _, flow_options, circuit_options = Trailblazer::Developer::Wtf::Invoke.add_trim_trace({}, flow_options, circuit_options)
    _, flow_options, circuit_options = Trailblazer::Activity::Invoke.produce_wrap_runtime({}, flow_options, circuit_options)

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
          # id: :Create, # we currently compute the :id in {#produce_wtf_node}
        )
      end
    end

    # assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    # assert_equal signal.to_h[:semantic], :success

puts output
assert_equal output,
"\e[30mCreate\e[0m
`-- \e[37mtask_wrap.call_task\e[0m
    |-- \e[32ma\e[0m
    |   `-- \e[32mtask_wrap.call_task\e[0m
    |       |-- \e[30minvoke_provider\e[0m
    |       |-- \e[30mis_signal?\e[0m
    |       `-- \e[32mcompute_binary_signal\e[0m
    `-- \e[37mb\e[0m
        `-- \e[37mtask_wrap.call_task\e[0m
            `-- \e[31m\e[1minvoke_provider\e[0m
"
  end

  it "what" do
    raise "allow correct coloring for nested activities "
  end

  describe "Developer.wtf?" do
    it "provides the Developer.wtf? method that uses the canonical debug pipe" do
      output, _ = capture_io do
        assert_raises RuntimeError do # FIXME: use our own error to test we're raising it.
          Trailblazer::Developer.wtf?(my_abc_activity, {seq: [], raise_from_b: true},
            id: :Create) # FIXME: where does ID come from? canonical invoke!
        end
      end

      assert_equal output,
"\e[30mCreate\e[0m
`-- \e[37mtask_wrap.call_task\e[0m
    |-- \e[32ma\e[0m
    |   `-- \e[32mtask_wrap.call_task\e[0m
    |       |-- \e[30minvoke_provider\e[0m
    |       |-- \e[30mis_signal?\e[0m
    |       `-- \e[32mcompute_binary_signal\e[0m
    `-- \e[37mb\e[0m
        `-- \e[37mtask_wrap.call_task\e[0m
            `-- \e[31m\e[1minvoke_provider\e[0m
"
    end

    it "wtf with a step returning an illegal signal (error on library level, in routing)" do
      my_activity = Class.new(Trailblazer::Activity::Railway) do
        step task: T.def_tasks(:a).method(:a), id: :a
      end

      output, _ = capture_io do
        assert_raises KeyError do # FIXME: use our own error to test we're raising it.
          Trailblazer::Developer.wtf?(my_activity, {seq: [], a: Trailblazer::Activity::Signal},
            only_application: true,
            id: :Create
          )
        end
      end

      # Problem here is, there is no Node::Incomplete to detect an error, since the {:a} task is finished and we get an error afterwards.
      assert_equal output, %(\e[37mCreate\e[0m
`-- \e[31m\e[1ma\e[0m
)
    end

    it "Developer.wtf? can use an option to trace only business nodes" do
      output, _ = capture_io do
        lib_ctx, flow_options, signal = Trailblazer::Developer.wtf?(my_abc_activity, {seq: []}, id: :Create, only_application: true)

        assert_equal lib_ctx, {target_ctx: {seq: [:a, :b, :c]}}
        assert_equal signal, my_abc_activity.to_h[:outputs][:success].signal
        assert_equal flow_options[:stack].to_a.size, 10   # TODO: better test.
      end

      puts output
      assert_equal output,
%(\e[30mCreate\e[0m
|-- \e[32ma\e[0m
|-- \e[32mb\e[0m
|-- \e[32mc\e[0m
`-- \e[30mEnd.success\e[0m
)
    end

    it "raise and business nodes, only" do
      raise "test me"
    end

    it "returns the circuit interface return set" do
      output, _ = capture_io do
        lib_ctx, flow_options, signal = Trailblazer::Developer.wtf?(my_abc_activity, {seq: []}, id: :Create)

        assert_equal lib_ctx, {target_ctx: {seq: [:a, :b, :c]}}
        assert_equal signal, my_abc_activity.to_h[:outputs][:success].signal
        assert_equal flow_options[:stack].to_a.size, 50 # TODO: better test.
        assert_equal flow_options[:trace].to_a.size, 19 # TODO: better test.
      end

      puts output
      assert_equal output, %(\e[30mCreate\e[0m
`-- \e[30mtask_wrap.call_task\e[0m
    |-- \e[32ma\e[0m
    |   `-- \e[32mtask_wrap.call_task\e[0m
    |       |-- \e[30minvoke_provider\e[0m
    |       |-- \e[30mis_signal?\e[0m
    |       `-- \e[32mcompute_binary_signal\e[0m
    |-- \e[32mb\e[0m
    |   `-- \e[32mtask_wrap.call_task\e[0m
    |       |-- \e[30minvoke_provider\e[0m
    |       |-- \e[30mis_signal?\e[0m
    |       `-- \e[32mcompute_binary_signal\e[0m
    |-- \e[32mc\e[0m
    |   `-- \e[32mtask_wrap.call_task\e[0m
    |       |-- \e[30minvoke_provider\e[0m
    |       |-- \e[30mis_signal?\e[0m
    |       `-- \e[32mcompute_binary_signal\e[0m
    `-- \e[30mEnd.success\e[0m
        `-- \e[30mtask_wrap.call_task\e[0m
)
    end

    # DISCUSS: technically, this
    it "{:renderer} can see {:variable_versions} from Stack" do
      my_operation = Class.new(Trailblazer::Operation) do
        step :a
        step :b,
          In() => [:seq],
          Out() => [:seq]

        include T.def_steps(:a)

        def b(ctx, seq:, **)
          ctx[:pollute] = true
          ctx[:seq] += [:b]
        end
      end

      my_renderer = ->(trace_node:, trace:, stack:, **) {
        variable_versions = stack.variable_versions # TODO: discuss API.

        ctx_before = Trailblazer::Developer::Trace::Snapshot.ctx_from_snapshot(trace_node.snapshot_before, variable_versions)
        ctx_after  = Trailblazer::Developer::Trace::Snapshot.ctx_from_snapshot(trace_node.snapshot_after, variable_versions)

        [trace_node.level, "#{trace_node.id} #{ctx_before} #{ctx_after}"]
      }

      result = nil
      output, _ = capture_io do
        result = my_operation.wtf?({seq: [1], rubbish: 1}, {flow_options: {renderer: my_renderer}}) # DISCUSS: do we like this signature?
      end

      # We can see the ctx *after* In() and *after* Out() in {b}.
      # assert_result result, true, seq: [1, :a, :b], rubbish: 1
      assert_equal result.success?, true
      assert_equal result.to_h, {seq: [1, :a, :b], rubbish: 1}

      # puts output
      assert_equal output.sub(/0x\w+/, ""), %(#<Class:> {:seq=>"[1]", :rubbish=>"1"} {:seq=>"[1, :a, :b]", :rubbish=>"1"}
|-- a {:seq=>"[1]", :rubbish=>"1"} {:seq=>"[1, :a]", :rubbish=>"1"}
|-- b {:seq=>"[1, :a]"} {:seq=>"[1, :a, :b]", :rubbish=>"1"}
`-- End.success {:seq=>"[1, :a, :b]", :rubbish=>"1"} {:seq=>"[1, :a, :b]", :rubbish=>"1"}
)
    end
  end
end
