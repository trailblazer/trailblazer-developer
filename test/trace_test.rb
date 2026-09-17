require "test_helper"

# require "trailblazer/invoke"
class TraceInvokeTest < Minitest::Spec
  it "traces a flat activity" do
     ctx, flow_options, signal, _ = kernel.__(
      flat_activity,
      {seq: []},
      **Trailblazer::Developer::Trace.options_for_canonical_invoke
    )

    assert_equal signal.to_h[:semantic], :success
    assert_equal CU.inspect(ctx.to_h), %({:seq=>[:B, :C]})

    stack = flow_options[:stack]
    output = Trailblazer::Developer::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    assert_equal output, %(#<Class:>
|-- Start.default
|-- B
|-- C
`-- End.success)
  end

  # TODO: can we add more {:wrap_runtime}?

  it "{Present}: you can pass an explicit task label via {:label}" do
    ctx, flow_options, signal, _ = kernel.__(flat_activity, {seq: []}, **Trailblazer::Developer::Trace.options_for_canonical_invoke)

    output = Dev::Trace::Present.(flow_options[:stack]) do |trace_nodes:, **|
      {
        node_options: {
          trace_nodes[0] => {label: "#{flat_activity.class} (anonymous)"}
        }
      }
    end

    assert_equal output, %{Class (anonymous)
|-- Start.default
|-- B
|-- C
`-- End.success}
  end

  it "nested tracing" do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity(e_options: {Trailblazer::Activity::Railway.Out() => [:nil_value]})

    ctx, flow_options, signal = kernel.__(activity, {seq: []}, **Trailblazer::Developer::Trace.options_for_canonical_invoke)

    stack = flow_options[:stack]

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

  #@ we get ctx_snapshot for in and out
    ctx_for = Trailblazer::Developer::Trace::Snapshot.method(:snapshot_ctx_for)
    variable_versions = stack.variable_versions

    assert_equal ctx_for.(stack.to_a[3], variable_versions), {:seq=>{:value=>"[]", :has_changed=>false}}
    assert_equal ctx_for.(stack.to_a[4], variable_versions), {:seq=>{:value=>"[:a]", :has_changed=>true}}

    assert_equal ctx_for.(stack.to_a[23], variable_versions), {:seq=>{:value=>"[:a, :b, :c, :d]", :has_changed=>false}}
  #@ we see out snapshot after Out() filters, {:nil_value} in added in {Out()}
    assert_equal ctx_for.(stack.to_a[24], variable_versions), {:seq=>{:value=>"[:a, :b, :c, :d, :e]", :has_changed=>true}, :nil_value=>{:value=>"nil", :has_changed=>true}}

# TODO: test label explicitely
    output = Dev::Trace::Present.(stack) do |trace_nodes:, **|
      {
        node_options: {
          trace_nodes[0] => {label: "#{activity.superclass} (anonymous)"},
        }
      }
    end


    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    assert_equal output, %{Trailblazer::Activity::Railway (anonymous)
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
end

# Test {Trace.call} and {Trace::Present.call}
class TraceTest < Minitest::Spec
  class MyRunner < Trailblazer::Circuit::Node::Runner
    def self.call(node, lib_ctx, flow_options, signal, circuit_options)
      # raise if node.instance_variable_get(:@extended)

      return super if node.instance_variable_get(:@extended)

      wrap_runtime = circuit_options.fetch(:wrap_runtime)
      id = circuit_options.fetch(:id)

      node = Trailblazer::Circuit::Node[
        Trailblazer::Circuit::Builder.Circuit(
          [:"task_wrap.call_task", node: node]
        ),
        Trailblazer::Circuit::Processor
      ]

      # pp node
      # raise

      puts "@@@@@ #{circuit_options[:id].inspect}"

      # DISCUSS: use super here?

      node_attrs = node.to_h

      node_attrs = Trailblazer::Circuit::WrapRuntime::Runner.extend_task_wrap_pipeline(wrap_runtime, id, node, node_attrs)

      node = node.class.new(**node_attrs)
      node.instance_variable_set(:@extended, true)

      node.task.nodes[:"task_wrap.call_task"].instance_variable_set(:@extended, true)

      super
    end
  end

  # This is for people who were using Developer::Trace.(MyActivity) to trace on their own.
  it "allows tracing by manually passing the options" do

    require "trailblazer/activity/variable_mapping"
    my_abc_activity = Class.new(Trailblazer::Activity::Railway) do
      _, builder, helper_forwarder = Trailblazer::Activity::DSL::Topology.build(
        builder: config.builder,
        default_options: {adds_for_task_wrap: []}, # needed by :apply_adds_to_task_wrap_pipeline

        helpers: {
          Trailblazer::Activity::VariableMapping::DSL::Helper => [:In, :Out, :Inject]
        },
        adds: [
          # FIXME: the next step should be already there by Path/canonical.
          # extension/task_wrap
          [:apply_adds_to_task_wrap_pipeline, Trailblazer::Activity::DSL::Feature::Extension::TaskWrap::Normalizer::Node, :before, :build_task_wrap_node],

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
      wrap_runtime: Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions),
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
%(...Create
`-- ...task_wrap.call_task
    |-- ...a
    |   `-- ...task_wrap.call_task
    |       |-- ...invoke_provider
    |       |-- ...is_signal?
    |       `-- ...compute_binary_signal
    |-- ...b
    |   |-- ...variable_mapping.input
    |   |   |-- ...in.seq > seq
    |   |   |   |-- ...invoke_provider
    |   |   |   |   `-- ...invoke_provider
    |   |   |   |-- ...wrap_value_with_hash
    |   |   |   `-- ...add_value_to_aggregate
    |   |   `-- ...input.scope
    |   |-- ...task_wrap.call_task
    |   |   |-- ...invoke_provider
    |   |   |-- ...is_signal?
    |   |   `-- ...compute_binary_signal
    |   `-- ...variable_mapping.output
    |       |-- ...output.default_output
    |       `-- ...output.merge_with_original
    |-- ...c
    |   `-- ...task_wrap.call_task
    |       |-- ...invoke_provider
    |       |-- ...is_signal?
    |       `-- ...compute_binary_signal
    `-- ...End.success
        `-- ...task_wrap.call_task)






# FIXME: move to node_test?
    # trace_nodes = Trailblazer::Developer::Trace.build_nodes(stack.to_a)
    # pp trace_nodes
    # raise
    # TODO: test changeset etc, the way it's done in node_test.

    # FIXME: testing Incomplete
    broken_stack = stack.to_a.to_a[0..8]
    # this is done in #wtf?
    trace_nodes = Trailblazer::Developer::Trace.build_nodes(broken_stack, segmenter: Trailblazer::Developer::Trace::Node::Incomplete.method(:segmenter)) # we break at :a#compute_binary_signal.
    # pp trace_nodes

    assert_equal trace_nodes.size, 7
    assert_trace_node trace_nodes[0], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 0, id: "...Create", snapshot_before: broken_stack[0][1], snapshot_after: nil
    assert_trace_node trace_nodes[1], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 1, id: "...task_wrap.call_task", snapshot_before: broken_stack[1][1], snapshot_after: nil
    assert_trace_node trace_nodes[2], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 2, id: "...a", snapshot_before: broken_stack[2][1], snapshot_after: nil
    assert_trace_node trace_nodes[3], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 3, id: "...task_wrap.call_task", snapshot_before: broken_stack[3][1], snapshot_after: nil
    assert_trace_node trace_nodes[4], level: 4, id: "...invoke_provider", snapshot_before: broken_stack[4][1], snapshot_after: broken_stack[5][1]
    assert_trace_node trace_nodes[5], level: 4, id: "...is_signal?", snapshot_before: broken_stack[6][1], snapshot_after: broken_stack[7][1]
    assert_trace_node trace_nodes[6], node_class: Trailblazer::Developer::Trace::Node::Incomplete, level: 4, id: "...compute_binary_signal", snapshot_before: broken_stack[8][1], snapshot_after: nil










  # we can also limit tracing to "business nodes".

    my_resolver = Struct.new(:node_wrap_resolver) do
      def [](node:, **circuit_options)
        return unless node.options[:business_step]

        node_wrap_resolver[node: node, **circuit_options]
      end
    end.new(Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions))

    flow_options = {
      stack:              Trailblazer::Developer::Trace::Stack.new,
      value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
    }
    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      flow_options,
      nil,
      runner: runner,
      wrap_runtime: my_resolver,
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

raise "make Present figure out the ID of the step instead of the generic {task_wrap.call_task}"
    assert_equal output, %(Create
|-- a
|-- b
|-- c
`-- End.success)
  end

  # FIXME: move to node_test.
  def assert_trace_node(node, node_class: Trailblazer::Developer::Trace::Node, **attrs)
    assert_equal node.class, node_class
    assert_equal node.to_h, attrs
  end
end

# Test specific options such as {:snapshooter}.
# class TraceAPITest < Minitest::Spec
#   # Test custom classes without explicit {#hash} implementation.
#   class User
#     def initialize(id)
#       @id = id
#     end
#   end

#   class Endpoint < Trailblazer::Activity::Railway
#     class Create < Trailblazer::Activity::Railway
#       step :model
#       step :screw_params! # unfortunately, people do that.

#       def model(ctx, current_user:, seq:, **)
#         seq << :model

#         ctx[:model] = Object
#       end

#       def screw_params!(ctx, params:, seq:, **)
#         seq << :screw_params!

#         # DISCUSS: this sucks, of course!
#         params[:song] = params
#       end
#     end


#     step :authenticate
#     step :authorize,
#       Inject(:current_user, override: true) => ->(ctx, **) { User.new(2) }, #
#       Inject() => [:seq],
#       Out() => []
#     step Subprocess(Create),
#       In() => [:current_user, :params, :seq],
#       Out() => [:model]

#     def authenticate(ctx, current_user:, seq:, **)
#       seq << :authenticate
#     end

#     def authorize(ctx, current_user:, seq:, **)
#       seq << :authorize
#     end
#   end

#   it "nested tracing with better-snapshot" do
#     Snapshot = Trailblazer::Developer::Trace::Snapshot

#     snapshot_flow_options = {
#       before_snapshooter:   Snapshot.method(:before_snapshooter),
#       after_snapshooter:  Snapshot.method(:after_snapshooter),
#     }

#     ctx, flow_options, signal = kernel.__(
#       Endpoint,
#       {
#         current_user: current_user = User.new(1),
#         params: {name: "Q & I"},
#         seq: [],
#       },
#       **Trailblazer::Developer::Trace.options_for_canonical_invoke
#     )


#     assert_equal ctx[:seq], [:authenticate, :authorize, :model, :screw_params!]

#     stack_object = flow_options[:stack]
#     stack = stack_object.to_a

# # pp stack.to_h
#     versions = stack_object.variable_versions.instance_variable_get(:@variables)
#     # pp versions

#     # Check if Ctx.snapshot_at works as expected.
#     assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(stack[11], stack_object.variable_versions), # asserted snapshot is for {After(:model)}.
#       {
#         current_user: {value: current_user.inspect, has_changed: false},
#         params:       {value: {:name=>"Q & I"}.inspect, has_changed: false},
#         seq:          {value: "[:authenticate, :authorize, :model]", has_changed: true},
#         model:        {value: "Object", has_changed: true}
#       }


#     # This is a unit test we might not need anymore:
#     assert_equal stack[0].task, Endpoint
#     assert_snapshot versions, stack[0], current_user: 0, params: 0, seq: 0

#     assert_equal stack[1].task.inspect, %(#<Trailblazer::Activity::Start semantic=:default>)
#     assert_snapshot versions, stack[1], current_user: 0, params: 0, seq: 0
#     assert_equal stack[2].task.inspect, %(#<Trailblazer::Activity::Start semantic=:default>)
#     assert_snapshot versions, stack[2], current_user: 0, params: 0, seq: 0

#     # Endpoint #authenticate
#     assert_equal CU.strip(stack[3].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authenticate>>>)
#     assert_snapshot versions, stack[3], current_user: 0, params: 0, seq: 0
#     assert_equal CU.strip(stack[4].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authenticate>>>)
#     assert_snapshot versions, stack[4], current_user: 0, params: 0, seq: 1

#     # Endpoint #authorize
#     assert_equal CU.strip(stack[5].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authorize>>>)
#     assert_snapshot versions, stack[5], current_user: 1, params: 0, seq: 1
#     assert_equal CU.strip(stack[6].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authorize>>>)
#     assert_snapshot versions, stack[6], current_user: 0, params: 0, seq: 2

#     # Create {in}
#     assert_equal stack[7].task,  Endpoint::Create
#     assert_snapshot versions, stack[7], current_user: 0, params: 0, seq: 2

#       # Create :model
#       assert_equal CU.strip(stack[10].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:model>>>)
#       assert_snapshot versions, stack[10], current_user: 0, params: 0, seq: 2
#       assert_equal CU.strip(stack[11].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:model>>>)
#       assert_snapshot versions, stack[11], current_user: 0, params: 0, seq: 3, model: 0

#       # Create :screw_params!
#       assert_equal CU.strip(stack[12].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:screw_params!>>>)
#       assert_snapshot versions, stack[12], current_user: 0, params: 0, seq: 3, model: 0
#       assert_equal CU.strip(stack[13].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:screw_params!>>>)
#       assert_snapshot versions, stack[13], current_user: 0, params: 1, seq: 4, model: 0

#       # Create End.success
#       assert_equal stack[15].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
#       assert_snapshot versions, stack[15], current_user: 0, params: 1, seq: 4, model: 0

#     # Create {out}
#     assert_equal stack[16].task, Endpoint::Create
#     assert_snapshot versions, stack[16], current_user: 0, params: 1, seq: 4, model: 0

#     # Endpoint End.success
#     assert_equal stack[17].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
#     assert_snapshot versions, stack[17], current_user: 0, params: 1, seq: 4, model: 0
#     assert_equal stack[18].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
#     assert_snapshot versions, stack[18], current_user: 0, params: 1, seq: 4, model: 0
#   end

#   def assert_snapshot(versions, snapshot, **expected_variable_names_to_expected_index)
#     captured_refs = snapshot.data[:ctx_variable_changeset] # [[variable_name, hash]]

#     assert_equal captured_refs.collect { |name, hash| name }, expected_variable_names_to_expected_index.keys

#     expected_variable_names_to_expected_index.each do |variable_name, index|
#       assert_equal versions.fetch(variable_name).keys[index], captured_refs.find { |name, hash| name == variable_name }[1], # both hashs have to be identical
#         "hash mismatch for `#{variable_name}`"
#     end
#   end

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
