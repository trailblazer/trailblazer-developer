require "test_helper"

# Test {Trace.call} and {Trace::Present.call}
class TraceTest < Minitest::Spec
  def my_abc_activity
    require "trailblazer/activity/variable_mapping"
    my_abc_activity = Class.new(Trailblazer::Activity::Railway) do
      _, _, builder, helper_forwarder = Trailblazer::Activity::DSL::Topology.build(
        builder: config.builder,
        default_options: {},

        helpers: {
          Trailblazer::Activity::VariableMapping::DSL::Helper => [:In, :Out, :Inject]
        },
        adds: [
          [
            :variable_mapping, Trailblazer::Activity::VariableMapping::DSL::Normalizer::Node,
            :before, :normalize_wirings
          ],
        ],
      )

      config.builder = builder
      extend helper_forwarder

      step :a
      step :b,
        In() => [:seq]
      step :c

      include T.def_steps(:a, :b, :c)
    end
  end

  def my_a_b_activity
    my_c = Class.new(Trailblazer::Activity::Railway) do
      step task: T.def_tasks(:c).method(:c), id: :c
    end

    my_b = Class.new(Trailblazer::Activity::Railway) do
      step Subprocess(my_c), id: :C
      step task: T.def_tasks(:b).method(:b), id: :b
    end

    Class.new(Trailblazer::Activity::Railway) do
      step :a
      step Subprocess(my_b), id: :B
      include T.def_steps(:a)
    end
  end

  it "Trace.build_nodes" do # DISCUSS: can't we use a higher abstraction for testing the nodes?
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(my_a_b_activity, {target_ctx: {seq: []}}, extensions: [], id: :Create, compiler: my_compiler)

    assert_equal signal, my_a_b_activity.to_h[:outputs][:success].signal
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :c, :b]

     # FIXME: testing Incomplete
    stack = flow_options[:stack]#.to_a.to_a[0..8]

    # this is done in #wtf?
    trace_nodes = Trailblazer::Developer::Trace.build_nodes(stack, segmenter: Trailblazer::Developer::Trace::Node::Incomplete.method(:segmenter)) # we break at :a#compute_binary_signal.

    snapshots = stack.to_a.to_a

    assert_equal trace_nodes.size, 21 # stack has 42 elements
    assert_trace_node trace_nodes[0], level: 0, id: :Create, snapshot_before: snapshots[0][1], snapshot_after: snapshots[41][1]
    assert_trace_node trace_nodes[1], level: 1, id: :"task_wrap.call_task", snapshot_before: snapshots[1][1], snapshot_after: snapshots[40][1] # Create.call_task
    assert_trace_node trace_nodes[2], level: 2, id: :a, snapshot_before: snapshots[2][1], snapshot_after: snapshots[11][1] # :a
    assert_trace_node trace_nodes[3], level: 3, id: :"task_wrap.call_task", snapshot_before: snapshots[3][1], snapshot_after: snapshots[10][1] # :a.call_task
    assert_trace_node trace_nodes[4], level: 4, id: :invoke_provider, snapshot_before: snapshots[4][1], snapshot_after: snapshots[5][1] # :invoke_provider
    assert_trace_node trace_nodes[5], level: 4, id: :is_signal?, snapshot_before: snapshots[6][1], snapshot_after: snapshots[7][1] # :is_signal?
    assert_trace_node trace_nodes[6], level: 4, id: :compute_binary_signal, snapshot_before: snapshots[8][1], snapshot_after: snapshots[9][1] # :compute_binary_signal

    assert_trace_node trace_nodes[7], level: 2, id: :B, snapshot_before: snapshots[12][1], snapshot_after: snapshots[35][1] # :B
    assert_trace_node trace_nodes[8], level: 3, id: :"task_wrap.call_task", snapshot_before: snapshots[13][1], snapshot_after: snapshots[34][1] # :B.call_task
    assert_trace_node trace_nodes[9], level: 4, id: :C, snapshot_before: snapshots[14][1], snapshot_after: snapshots[25][1] # :C

    assert_trace_node trace_nodes[10], level: 5, id: :"task_wrap.call_task", snapshot_before: snapshots[15][1], snapshot_after: snapshots[24][1] # :C.call_task
    assert_trace_node trace_nodes[11], level: 6, id: :c, snapshot_before: snapshots[16][1], snapshot_after: snapshots[19][1] # :c "task_wrap"
    assert_trace_node trace_nodes[12], level: 7, id: :"task_wrap.call_task", snapshot_before: snapshots[17][1], snapshot_after: snapshots[18][1] # :c.call_task

    assert_trace_node trace_nodes[13], level: 6, id: :"End.success", snapshot_before: snapshots[20][1], snapshot_after: snapshots[23][1] # :End.success
    assert_trace_node trace_nodes[14], level: 7, id: :"task_wrap.call_task", snapshot_before: snapshots[21][1], snapshot_after: snapshots[22][1] # :End.success.call_task

    assert_trace_node trace_nodes[15], level: 4, id: :b, snapshot_before: snapshots[26][1], snapshot_after: snapshots[29][1] # :b "task_wrap"
    assert_trace_node trace_nodes[16], level: 5, id: :"task_wrap.call_task", snapshot_before: snapshots[27][1], snapshot_after: snapshots[28][1] # :b.call_task

    assert_trace_node trace_nodes[17], level: 4, id: :"End.success", snapshot_before: snapshots[30][1], snapshot_after: snapshots[33][1] # :End.success
    assert_trace_node trace_nodes[18], level: 5, id: :"task_wrap.call_task", snapshot_before: snapshots[31][1], snapshot_after: snapshots[32][1] # :End.success.call_task

    assert_trace_node trace_nodes[19], level: 2, id: :"End.success", snapshot_before: snapshots[36][1], snapshot_after: snapshots[39][1] # :End.success
    assert_trace_node trace_nodes[20], level: 3, id: :"task_wrap.call_task", snapshot_before: snapshots[37][1], snapshot_after: snapshots[38][1] # :End.success.call_task
  end

  it "{Present.call} with complete stack" do
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(my_a_b_activity, {target_ctx: {seq: []}}, extensions: [], id: :Create, compiler: my_compiler)
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :c, :b]

    output = Trailblazer::Developer::Trace::Present.(flow_options[:stack])
    puts output

    assert_equal output,
%(Create
`-- task_wrap.call_task
    |-- a
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    |-- B
    |   `-- task_wrap.call_task
    |       |-- C
    |       |   `-- task_wrap.call_task
    |       |       |-- c
    |       |       |   `-- task_wrap.call_task
    |       |       `-- End.success
    |       |           `-- task_wrap.call_task
    |       |-- b
    |       |   `-- task_wrap.call_task
    |       `-- End.success
    |           `-- task_wrap.call_task
    `-- End.success
        `-- task_wrap.call_task)
  end

  it "{Present.call} with Incomplete stack" do
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(my_a_b_activity, {target_ctx: {seq: []}}, extensions: [], id: :Create, compiler: my_compiler)

    assert_equal signal, my_a_b_activity.to_h[:outputs][:success].signal
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :c, :b]

    stack = flow_options[:stack].to_a.to_a[0..13]

    # this is done in #wtf?
    trace_nodes = Trailblazer::Developer::Trace.build_nodes(stack, segmenter: Trailblazer::Developer::Trace::Node::Incomplete.method(:segmenter)) # we break at :a#compute_binary_signal.

    snapshots = stack

    assert_equal trace_nodes.size, 9
    assert_trace_node trace_nodes[0], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 0, id: :Create, snapshot_before: stack[0][1], snapshot_after: nil
    assert_trace_node trace_nodes[1], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 1, id: :"task_wrap.call_task", snapshot_before: stack[1][1], snapshot_after: nil
    assert_trace_node trace_nodes[2], level: 2, id: :a, snapshot_before: stack[2][1], snapshot_after: stack[11][1]
    assert_trace_node trace_nodes[3], level: 3, id: :"task_wrap.call_task", snapshot_before: stack[3][1], snapshot_after: stack[10][1]
    assert_trace_node trace_nodes[4], level: 4, id: :invoke_provider, snapshot_before: stack[4][1], snapshot_after: stack[5][1]
    assert_trace_node trace_nodes[5], level: 4, id: :is_signal?, snapshot_before: stack[6][1], snapshot_after: stack[7][1]
    assert_trace_node trace_nodes[6], level: 4, id: :compute_binary_signal, snapshot_before: stack[8][1], snapshot_after: stack[9][1]
    assert_trace_node trace_nodes[7], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 2, id: :B, snapshot_before: stack[12][1], snapshot_after: nil
    assert_trace_node trace_nodes[8], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 3, id: :"task_wrap.call_task", snapshot_before: stack[13][1], snapshot_after: nil
  end

  it "we can also limit tracing to business nodes by using a custom condition in the Resolver" do
    # my_resolver = Trailblazer::Circuit::WrapRuntime::Extension::Resolver.new(
    #   default_extension_set: my_extensions,
    #   )

    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(my_a_b_activity, {target_ctx: {seq: []}}, extensions: [], id: :Create, compiler: my_compiler,
      conditions: [Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION, ->(node:, **) { node.options[:business_step] }]
    )
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :c, :b]

    output = Trailblazer::Developer::Trace::Present.(flow_options[:stack])
    # puts output
    assert_equal output, %(Create
|-- a
|-- B
|   |-- C
|       |-- c
|       `-- End.success
|   |-- b
|   |-- End.success
`-- End.success)
  end

  # This is for people who were using Developer::Trace.(MyActivity) to trace on their own.
  # FIXME: THIS IS A FULL-BLOWN INTEGRATION TEST vv
  it "allows tracing by manually passing the options" do
    my_abc_activity_node = Trailblazer::Circuit::Node[my_abc_activity, Trailblazer::Circuit::Processor]

    # my_abc_activity_node.task.instance_variable_set(:@pipe, true) # FIXME: this is used in WrapRuntime::Runner.
    my_canonical_Create_tw_node = Trailblazer::Circuit::Node[
      Trailblazer::Circuit::Builder.Pipeline(
        [:"task_wrap.call_task", node: my_abc_activity_node]
      ),
      Trailblazer::Circuit::Processor
    ]

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
      {target_ctx: {seq: []}},
      flow_options,
      nil,
      runner: runner,
      wrap_runtime: Trailblazer::Circuit::WrapRuntime::Extension::Resolver.new(default_extension_set: my_extensions, conditions: [Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION]),
      context_implementation: Trailblazer::Circuit::Context,
      id: :Create,
      node: my_canonical_Create_tw_node,
    )

    assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    assert_equal signal.to_h[:semantic], :success

    stack = flow_options[:stack]









    # Debugging
    stack.to_a.each do |capture, _|
      # puts [capture, capture.object_id, capture.delimits.object_id].inspect
    end

    output = Trailblazer::Developer::Trace::Present.(stack)
    # output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")
puts output
assert_equal output,
%(Create
`-- task_wrap.call_task
    |-- a
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    |-- b
    |   |-- variable_mapping.input
    |   |   |-- in.seq > seq
    |   |   |   |-- invoke_provider
    |   |   |   |   `-- invoke_provider
    |   |   |   |-- wrap_value_with_hash
    |   |   |   `-- add_value_to_aggregate
    |   |   `-- input.scope
    |   |-- task_wrap.call_task
    |   |   |-- invoke_provider
    |   |   |-- is_signal?
    |   |   `-- compute_binary_signal
    |   `-- variable_mapping.output
    |       |-- output.default_output
    |       `-- output.merge_with_original
    |-- c
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    `-- End.success
        `-- task_wrap.call_task)
  end

  it "can be used with Activity::Invoke.(). we can pass our options from the outside." do
    _, flow_options, circuit_options = Trailblazer::Developer::Trace::Invoke.add_options_for_trace({}, {}, {extensions: []})

    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(
      my_abc_activity,
      {target_ctx: {seq: []}}, # DISCUSS: we are passing the lib_ctx here, not "application_ctx".

      flow_options: flow_options,
      **circuit_options,
      id: :Create,
    )

    assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    assert_equal signal.to_h[:semantic], :success

    stack = flow_options[:stack]

    output = Trailblazer::Developer::Trace::Present.(stack)

    assert_equal output,
%(Create
`-- task_wrap.call_task
    |-- a
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    |-- b
    |   |-- variable_mapping.input
    |   |   |-- in.seq > seq
    |   |   |   |-- invoke_provider
    |   |   |   |   `-- invoke_provider
    |   |   |   |-- wrap_value_with_hash
    |   |   |   `-- add_value_to_aggregate
    |   |   `-- input.scope
    |   |-- task_wrap.call_task
    |   |   |-- invoke_provider
    |   |   |-- is_signal?
    |   |   `-- compute_binary_signal
    |   `-- variable_mapping.output
    |       |-- output.default_output
    |       `-- output.merge_with_original
    |-- c
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    `-- End.success
        `-- task_wrap.call_task)
  end

  # DISCUSS: not sure this test needs to exist.
  it "we can also configure the canonical invoke pipeline to enable tracing based on ENV variables" do
    my_canonical_invoke = Trailblazer::Circuit::Adds.(
      Trailblazer::Activity::Invoke::Args::Compiler,
      [:my_trace, Trailblazer::Circuit::Node[Trailblazer::Developer::Trace::Invoke.method(:add_options_for_trace), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime]
    )

    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(
      my_abc_activity,
      {target_ctx: {seq: []}}, # DISCUSS: we are passing the lib_ctx here, not "application_ctx".

      # flow_options: flow_options,
      # **circuit_options,
      id: :Create,
      compiler: my_canonical_invoke,
      extensions: []
    )

    assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}
    assert_equal signal.to_h[:semantic], :success

    stack = flow_options[:stack]

    output = Trailblazer::Developer::Trace::Present.(stack)

    assert_equal output,
%(Create
`-- task_wrap.call_task
    |-- a
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    |-- b
    |   |-- variable_mapping.input
    |   |   |-- in.seq > seq
    |   |   |   |-- invoke_provider
    |   |   |   |   `-- invoke_provider
    |   |   |   |-- wrap_value_with_hash
    |   |   |   `-- add_value_to_aggregate
    |   |   `-- input.scope
    |   |-- task_wrap.call_task
    |   |   |-- invoke_provider
    |   |   |-- is_signal?
    |   |   `-- compute_binary_signal
    |   `-- variable_mapping.output
    |       |-- output.default_output
    |       `-- output.merge_with_original
    |-- c
    |   `-- task_wrap.call_task
    |       |-- invoke_provider
    |       |-- is_signal?
    |       `-- compute_binary_signal
    `-- End.success
        `-- task_wrap.call_task)
  end

  # DISCUSS: move to node_test.
  def assert_trace_node(node, node_class: Trailblazer::Developer::Trace::Node, snapshot_before:, snapshot_after:, **attrs)
    assert_equal node.class, node_class


    actual_attrs = node.to_h
    actual_attrs = actual_attrs.merge(snapshot_before: actual_attrs[:snapshot_before].object_id, snapshot_after: actual_attrs[:snapshot_after].object_id)

    assert_equal actual_attrs, attrs.merge(snapshot_before: snapshot_before.object_id, snapshot_after: snapshot_after.object_id)
  end

  it "what" do
    raise "Trace should add another extension to figure out the runtime path, not just the ID"
  end
end

# Test specific options such as {:snapshooter}.
# class TraceAPITest < Minitest::Spec
#



#   it "snapshot works with {nil} values" do
#     activity = Class.new(Trailblazer::Activity::Railway) do
#       pass :override
#       step :create

#       def override(ctx, **)
#         ctx[:model] = nil
#       end

#       def create(ctx, **)
#         ctx[:model] = Object
#       end
#     end

#     ctx, flow_options, signal = kernel.__(activity, {}, **Trailblazer::Developer::Trace.options_for_canonical_invoke)

#     stack = flow_options[:stack]
#     nodes = stack.to_a

#     # :override/after
#     assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(nodes[4], stack.variable_versions),
#       {
#         model: {value: "nil", has_changed: true},
#       }

#     # :create/after
#     assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(nodes[6], stack.variable_versions),
#       {
#         model: {value: "Object", has_changed: true},
#       }
#   end

#   it "{:value_snapshooter} allows injecting new matcher/inspect tuple" do
#     value_snapshooter = Trailblazer::Developer::Trace::Snapshot::Value.build
#     value_snapshooter.instance_variable_get(:@matchers).unshift [ # TODO: public interface.
#       ->(name, value, ctx:) { value.is_a?(Module) },
#       ->(name, value, ctx:) { "Module class" }
#     ]

#     activity = Class.new(Trailblazer::Activity::Railway) do
#       step :create

#       def create(ctx, **)
#         ctx[:model] = Module
#       end
#     end

#     ctx, flow_options, signal = kernel.__(
#       activity,
#       {params: {}},
#       **Trailblazer::Developer::Trace.options_for_canonical_invoke,
#       flow_options: {
#         value_snapshooter: value_snapshooter
#       }
#     )

#     stack = flow_options[:stack]
#     nodes = stack.to_a

#     # Op/after
#     # :params is params.inspect
#     # :model was serialized with custom inspector.
#     assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(nodes[7], stack.variable_versions),
#       {
#         :params=>{:value=>"{}", :has_changed=>false},
#         :model=>{:value=>"Module class", :has_changed=>false}
#       }


#   # We can also set it via {Trace.value_snapshooter}
#     Trailblazer::Developer::Trace.instance_variable_set(:@value_snapshooter, value_snapshooter)

#     ctx, flow_options, signal = kernel.__(activity, {params: {}}, **Trailblazer::Developer::Trace.options_for_canonical_invoke)

#     stack = flow_options[:stack]
#     nodes = stack.to_a

#     # Op/after
#     # :params is params.inspect
#     # :model was serialized with custom inspector.
#     assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(nodes[7], stack.variable_versions),
#       {
#         :params=>{:value=>"{}", :has_changed=>false},
#         :model=>{:value=>"Module class", :has_changed=>false}
#       }

#     Trailblazer::Developer::Trace.instance_variable_set(:@value_snapshooter, Trailblazer::Developer::Trace::Snapshot::Value.build) # reset to original value.
#   end

#   it "allows to inject custom data collector" do
#     input_collector = ->(wrap_ctx, flow_options, _) { [{ ctx: wrap_ctx[:application_ctx].to_h, something: :else }, {}] }
#     output_collector = ->(wrap_ctx, flow_options, _) { [{ ctx: wrap_ctx[:application_ctx].to_h, signal: wrap_ctx[:return_signal] }, {}] }

#     ctx, flow_options, signal = kernel.__(
#       flat_activity,
#       {seq: []},
#       **Trailblazer::Developer::Trace.options_for_canonical_invoke(),
#       flow_options: { # those are merged by options-compiler.
#         before_snapshooter: input_collector,
#         after_snapshooter: output_collector,
#       }
#     )

#     assert_equal ctx[:seq], [:B, :C]

#     stack = flow_options[:stack].to_a
#     captured_input  = stack[0]
#     captured_output = stack[-1]
#     # pp stack

#     assert_equal captured_input.data, { ctx: { seq: [:B, :C] }, something: :else }
#     assert_equal captured_output.data, { ctx: { seq: [:B, :C] }, signal: signal }
#   end
# end
