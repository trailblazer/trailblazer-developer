require "test_helper"

class TraceWtfTest < Minitest::Spec
  it "what" do
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

    class Node < Trailblazer::Circuit::Node
      def call(lib_ctx, flow_options, signal, **circuit_options)
        exception = false

        begin
          super
        rescue
  puts "rescue!!!!"
          exception = $!
        end

        output = Trailblazer::Developer::Trace::Present.(flow_options[:stack], segmenter: Trailblazer::Developer::Trace::Node::Incomplete.method(:segmenter))
        puts output
        raise exception if exception

        return lib_ctx, flow_options, signal
      end
    end

    my_wtf_circuit_fixme = Trailblazer::Circuit::Builder.Pipeline(
      [:wtf_top_canonical, node: my_canonical_Create_tw_node]
    )
    my_wtf_node = Node[my_wtf_circuit_fixme, Trailblazer::Circuit::Processor]

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

    assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    assert_equal signal.to_h[:semantic], :success

    stack = flow_options[:stack]

    output = Trailblazer::Developer::Trace::Present.(stack)
    # output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")
puts output
assert_equal output,
%(...Create
`-- ...task_wrap.call_task
    |-- ...a
    |   `-- ...task_wrap.call_task
    |       |-- ...invoke_provider
    |       |-- ...is_signal?
    |       `-- ...compute_binary_signal
    |-- ...b
    |   `-- ...task_wrap.call_task
    |       |-- ...invoke_provider
    |       |-- ...is_signal?
    |       `-- ...compute_binary_signal
    |-- ...c
    |   `-- ...task_wrap.call_task
    |       |-- ...invoke_provider
    |       |-- ...is_signal?
    |       `-- ...compute_binary_signal
    `-- ...End.success
        `-- ...task_wrap.call_task)
  end



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
    assert_equal CU.inspect(returned_args[0].to_h), %({:seq=>[:a, :b, :c], :c=>false})
    assert_equal returned_args[1].class, Hash # flow_options
    # assert_equal returned_args[2].keys.inspect, %([:container_activity, :exec_context, :wrap_runtime]) # circuit_options
    assert_equal returned_args[2].inspect, %(#<Trailblazer::Activity::End semantic=:failure>)
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

    signal, ctx, flow_options, output, returned_present_args = nil

    captured_output, _ = capture_io do
      ctx, flow_options, signal, output, returned_present_args = Trailblazer::Developer.wtf?(
        alpha,
        {seq: []},

        # Merged by options-compiler:
        circuit_options: {
          present_options: {render_method: my_renderer}
        }

        # This is an alternative API to squeeze your options into invoke:
        #
        # adds_for_options_compiler: [
        # [
        #   Trailblazer::Invoke::Options::HeuristicMerge.build(
        #     ->(*) do
        #       {
        #         circuit_options: {
        #           present_options: {render_method: my_renderer}
        #         }
        #       }
        #     end
        #   ),
        #   id: "user.wtf.present_options", append: nil
        # ]
        # ],

      )
    end

    assert_equal captured_output.chomp, %(Nodes: 15)
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_equal CU.inspect(ctx.to_h), %({:seq=>[:a, :b, :c, :cc, :bb, :aa]})
    # assert_equal circuit_options.keys.inspect, %([:container_activity, :exec_context, :wrap_runtime])
    assert_equal output, captured_output.chomp
    assert_equal returned_present_args, ["additional", "returned", "args"]
  end

  it "internally uses canonical invoke and creates a {Context}" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model

      def model(ctx, record:, **)
        ctx[:record_in_model] = record.inspect
      end
    end

    Trailblazer::Invoke.module!(activity.singleton_class) do # FIXME: do this for all Strategy subs.
      {
        flow_options: {
          context_options: {
            aliases: {"model": :record},
            container_class: Trailblazer::Context::Container::WithAliases,
          },
        }
      }
    end

    signal, ctx, flow_options, circuit_options, output, returned_present_args = nil

    captured_output, _ = capture_io do
      ctx, flow_options, signal, output, returned_present_args = Trailblazer::Developer.wtf?(
        activity,
        {seq: [], model: Module},
      )
    end

    assert_equal CU.inspect(ctx.to_h), %({:seq=>[], :model=>Module, :record=>Module, :record_in_model=>\"Module\"})
    assert_equal CU.strip(captured_output), %(#<Class:0x>
|-- \e[32mStart.default\e[0m
|-- \e[32mmodel\e[0m
`-- End.success\n)
  end

  it "passes {activity} to {Present}" do
    class PresentCreate < Trailblazer::Activity::Railway
    end
    Trailblazer::Invoke.module!(PresentCreate.singleton_class) # FIXME: do this for all Strategy subs.

    my_renderer = ->(debugger_trace:, activity:, **) { "Nodes: #{debugger_trace.to_a.size}, started at #{activity}" }

    ctx, flow_options, signal, output = Trailblazer::Developer.wtf?(
      PresentCreate,
      {},
      circuit_options: {
        present_options: {render_method: my_renderer}
      }
    )

    assert_equal output, %(Nodes: 3, started at TraceWtfTest::PresentCreate)
  end

  it "overrides default color map of entities" do
    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.

    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        {seq: [], c: false},
        flow_options: {color_map: { pass: :cyan, fail: :red } }
      )
    end

    assert_equal CU.strip(output), %(#<Class:0x>
|-- \e[36mStart.default\e[0m
|-- \e[36m#<Method: #<Class:>.a>\e[0m
|-- #<Class:0x>
|   |-- \e[36mStart.default\e[0m
|   |-- \e[36m#<Method: #<Class:>.b>\e[0m
|   |-- #<Class:0x>
|   |   |-- \e[36mStart.default\e[0m
|   |   |-- \e[31m#<Method: #<Class:>.c>\e[0m
|   |   `-- End.failure
|   `-- End.failure
`-- End.failure
)
  end

  it "has alias to `wtf` as `wtf?`" do
    assert_equal Dev.method(:wtf), Dev.method(:wtf?)
  end

  it "we can add to {:wrap_runtime} even with {wtf?}'s :wrap_runtime being set" do
    def add_1(wrap_ctx, flow_options, _)
      ctx = wrap_ctx[:application_ctx]
      ctx[:seq] << 1

      return wrap_ctx, flow_options # yay to mutable state. not.
    end

    Trailblazer::Invoke.module!(alpha.singleton_class) # FIXME: do this for all Strategy subs.
    ctx = nil

    output, _ = capture_io do
      ctx, _, signal = Trailblazer::Developer.wtf?(
        alpha,
        {seq: []},
        circuit_options: {wrap_runtime: Hash.new(Trailblazer::Activity::TaskWrap::Extension([method(:add_1), id: "my.add_1", append: nil]))}
      )
    end

    assert_equal CU.inspect(ctx.to_h), %({:seq=>[1, :a, 1, 1, :b, 1, 1, :c, 1, :cc, 1, 1, 1, :bb, 1, 1, 1, :aa, 1, 1, 1]})
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
end
