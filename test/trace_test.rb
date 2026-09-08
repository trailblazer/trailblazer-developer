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
  # This is for people who were using Developer::Trace.(MyActivity) to trace on their own.
  it "allows tracing by manually passing the options" do
    my_abc_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b
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
        my_tracing_extension_builder
      ]
    )

    flow_options = {
      stack:              Trailblazer::Developer::Trace::Stack.new,
      value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
    }

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      my_canonical_Create_tw_node,
      {target_ctx: {seq: []}},
      flow_options,
      nil,
      runner: Trailblazer::Circuit::WrapRuntime::Runner,
      wrap_runtime: Hash.new(my_extensions),
      context_implementation: Trailblazer::Circuit::Context,
      # exec_context: create_instance,
      id: :Create,
    )


    assert_equal lib_ctx, {:target_ctx=>{:seq=>[:a, :b, :c]}}

    # pp flow_options[:stack]

    assert_equal signal.to_h[:semantic], :success

    stack = flow_options[:stack]
    output = Trailblazer::Developer::Trace::Present.(stack)
    # output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    assert_equal output, %(Create
|-- a
|-- b
|-- c
`-- End.success)
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
