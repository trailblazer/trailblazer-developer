require "test_helper"

class TraceWtfTest < Minitest::Spec
  let(:alpha) do
    charlie = Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:c, :cc)

      step method(:c)
      step method(:cc)
    end

    beta = Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:b, :bb)

      step method(:b)
      step Subprocess(charlie)
      step method(:bb)
    end

    Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:a, :aa)

      step method(:a)
      step Subprocess(beta)
      step method(:aa)
    end
  end

  class Raiser < Array
    def initialize(raise_in:)
      super()
      @raise_in = raise_in
    end

    def <<(value)
      raise "hello from #{value}!" if value == @raise_in
      super
    end
  end

  it "traces until charlie, 3-level and exception occurs" do
    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.

    exception, returned_args = nil

    output, _ = capture_io do
      exception = assert_raises RuntimeError do
        returned_args = Trailblazer::Developer.wtf?(alpha, {seq: Raiser.new(raise_in: :c)})
      end
    end

    assert_equal exception.message, %(hello from c!)
    assert_nil returned_args

    assert_equal CU.strip(output), %(#<Class:0x>
|-- \e[32mStart.default\e[0m
|-- \e[32m#<Method: #<Class:>.a>\e[0m
`-- #<Class:0x>
    |-- \e[32mStart.default\e[0m
    |-- \e[32m#<Method: #<Class:>.b>\e[0m
    `-- #<Class:0x>
        |-- \e[32mStart.default\e[0m
        `-- \e[1m\e[31m#<Method: #<Class:>.c>\e[0m\e[22m
)
  end

  it "traces until charlie, 3-level and step takes left track" do
    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.

    returned_args = nil

    output, _ = capture_io do
      returned_args = Trailblazer::Developer.wtf?(alpha, {seq: [], c: false})
    end

    trace_output = %(#<Class:0x>
|-- \e[32mStart.default\e[0m
|-- \e[32m#<Method: #<Class:>.a>\e[0m
|-- #<Class:0x>
|   |-- \e[32mStart.default\e[0m
|   |-- \e[32m#<Method: #<Class:>.b>\e[0m
|   |-- #<Class:0x>
|   |   |-- \e[32mStart.default\e[0m
|   |   |-- \e[33m#<Method: #<Class:>.c>\e[0m
|   |   `-- End.failure
|   `-- End.failure
`-- End.failure)

    # test returned values for #wtf?
    assert_equal returned_args.size, 5
    assert_equal returned_args[0].inspect, %(#<Trailblazer::Activity::End semantic=:failure>)
    assert_equal CU.inspect(returned_args[1][0].to_h), %({:seq=>[:a, :b, :c], :c=>false})
    assert_equal returned_args[1][1].class, Hash # flow_options
    assert_equal returned_args[2].keys.inspect, %([:container_activity, :exec_context, :wrap_runtime]) # circuit_options
    assert_equal returned_args[3].chomp, output.chomp # fourth returned value is the trace output.
    assert_equal returned_args[4].inspect, %(nil)

    assert_equal CU.strip(output).chomp, trace_output
  end

  it "traces alpha and its subprocesses, for successful execution" do
    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.

    output, _ = capture_io do
      Trailblazer::Developer.wtf?(alpha, {seq: []})
    end

    assert_equal CU.strip(output), %(#<Class:0x>
|-- \e[32mStart.default\e[0m
|-- \e[32m#<Method: #<Class:>.a>\e[0m
|-- #<Class:0x>
|   |-- \e[32mStart.default\e[0m
|   |-- \e[32m#<Method: #<Class:>.b>\e[0m
|   |-- #<Class:0x>
|   |   |-- \e[32mStart.default\e[0m
|   |   |-- \e[32m#<Method: #<Class:>.c>\e[0m
|   |   |-- \e[32m#<Method: #<Class:>.cc>\e[0m
|   |   `-- End.success
|   |-- \e[32m#<Method: #<Class:>.bb>\e[0m
|   `-- End.success
|-- \e[32m#<Method: #<Class:>.aa>\e[0m
`-- End.success
)
  end

  it "accepts {:present_options}" do
    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.

    my_renderer = ->(debugger_trace:, **) {
      return "Nodes: #{debugger_trace.to_a.size}", ["additional", "returned", "args"]
    }

    signal, ctx, flow_options, circuit_options, output, returned_present_args = nil

    captured_output, _ = capture_io do
      signal, (ctx, flow_options), circuit_options, output, returned_present_args = Trailblazer::Developer.wtf?(
        alpha,
        {seq: []},
        adds_for_options_compiler: [
        [
          Trailblazer::Invoke::Options::HeuristicMerge.build(
            ->(*) do
              {
                circuit_options: {
                  present_options: {render_method: my_renderer}
                }
              }
            end
          ),
          id: "user.wtf.present_options", append: nil
        ]
      ],

      )
    end

    assert_equal captured_output.chomp, %(Nodes: 15)
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_equal CU.inspect(ctx.to_h), %({:seq=>[:a, :b, :c, :cc, :bb, :aa]})
    assert_equal circuit_options.keys.inspect, %([:container_activity, :exec_context, :wrap_runtime])
    assert_equal output, captured_output.chomp
    assert_equal returned_present_args, ["additional", "returned", "args"]
  end

  it "passes {activity} to {Present}" do
    class PresentCreate < Trailblazer::Activity::Railway
    end

    my_renderer = ->(debugger_trace:, activity:, **) { "Nodes: #{debugger_trace.to_a.size}, started at #{activity}" }

    signal, (ctx, flow_options), circuit_options, output = Trailblazer::Developer.wtf?(
      PresentCreate,
      [{}],
      present_options: {render_method: my_renderer})

    assert_equal output, %(Nodes: 3, started at TraceWtfTest::PresentCreate)
  end

  it "overrides default color map of entities" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], c: false },
          { color_map: { pass: :cyan, fail: :red } }
        ]
      )
    end

    _(output.gsub(/0x\w+/, "")).must_equal %{#<Class:>
|-- \e[36mStart.default\e[0m
|-- \e[36m#<Method: #<Class:>.a>\e[0m
|-- #<Class:>
|   |-- \e[36mStart.default\e[0m
|   |-- \e[36m#<Method: #<Class:>.b>\e[0m
|   |-- #<Class:>
|   |   |-- \e[36mStart.default\e[0m
|   |   |-- \e[31m#<Method: #<Class:>.c>\e[0m
|   |   `-- End.failure
|   `-- End.failure
`-- End.failure
}
  end

  it "supports circuit interface call definition and doesn't mutate any passed options" do
    ctx = { seq: [] }
    flow_options = { flow: true }
    circuit_options = { circuit: true }

    capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [ctx, flow_options],
        **circuit_options
      )
    end

    _(ctx).must_equal({ seq: [:a, :b, :c, :cc, :bb, :aa] })
    _(flow_options).must_equal({ flow: true })
    _(circuit_options).must_equal({ circuit: true })
  end

  it "has alias to `wtf` as `wtf?`" do
    assert_equal Dev.method(:wtf), Dev.method(:wtf?)
  end

  it "we can add to {:wrap_runtime" do
    raise
  end
end
