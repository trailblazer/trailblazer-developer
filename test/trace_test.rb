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
    ctx_for = Trailblazer::Developer::Trace::Snapshot::Ctx.method(:snapshot_ctx_for)
    variable_versions = stack.variable_versions

    assert_equal ctx_for.(stack.to_a[3], variable_versions), {:seq=>{:value=>"[]", :has_changed=>false}}
    assert_equal ctx_for.(stack.to_a[4], variable_versions), {:seq=>{:value=>"[:a]", :has_changed=>true}}

    assert_equal ctx_for.(stack.to_a[23], variable_versions), {:seq=>{:value=>"[:a, :b, :c, :d]", :has_changed=>false}}
  #@ we see out snapshot after Out() filters, {:nil_value} in added in {Out()}
    assert_equal ctx_for.(stack.to_a[24], variable_versions), {:seq=>{:value=>"[:a, :b, :c, :d, :e]", :has_changed=>true}, :nil_value=>{:value=>"nil", :has_changed=>true}}

# TODO: test label explicitely
    output = Dev::Trace::Present.(stack,
      node_options: {
        stack.to_a[0] => {label: "#{activity.superclass} (anonymous)"},
      }
    )

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

  it "nested tracing with better-snapshot" do
    # Test custom classes without explicit {#hash} implementation.
    class User
      def initialize(id)
        @id = id
      end
    end

    namespace = Module.new do
      class self::Endpoint < Trailblazer::Activity::Railway
        class Create < Trailblazer::Activity::Railway
          step :model
          step :screw_params! # unfortunately, people do that.

          def model(ctx, current_user:, seq:, **)
            seq << :model

            ctx[:model] = Object
          end

          def screw_params!(ctx, params:, seq:, **)
            seq << :screw_params!

            # DISCUSS: this sucks, of course!
            params[:song] = params
          end
        end


        step :authenticate
        step :authorize,
          Inject(:current_user, override: true) => ->(ctx, **) { User.new(2) }, #
          Inject() => [:seq],
          Out() => []
        step Subprocess(Create),
          In() => [:current_user, :params, :seq],
          Out() => [:model]

        def authenticate(ctx, current_user:, seq:, **)
          seq << :authenticate
        end

        def authorize(ctx, current_user:, seq:, **)
          seq << :authorize
        end
      end
    end

    Snapshot = Trailblazer::Developer::Trace::Snapshot

    inspect_only_flow_options = {
      before_snapshooter:   Snapshot::Deprecated.method(:default_input_data_collector),
      after_snapshooter:  Snapshot::Deprecated.method(:default_output_data_collector),
    }


    snapshot_flow_options = {
      before_snapshooter:   Snapshot.method(:before_snapshooter),
      after_snapshooter:  Snapshot.method(:after_snapshooter),
    }

    activity = namespace::Endpoint


# require "benchmark/ips"
# Benchmark.ips do |x|
#     x.report("inspect-only") do ||

#       stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
#         activity,
#         [
#           {seq: [], current_user: Object.new, params: {name: "Q & I"}},
#           inspect_only_flow_options
#         ]
#       )
#     end

#     x.report("snapshot") do ||

#       stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
#         activity,
#         [
#           {seq: [], current_user: Object.new, params: {name: "Q & I"}},
#           snapshot_flow_options
#         ]
#       )
#     end

#     x.compare!
# end


    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {
          current_user: current_user = User.new(1),
          params: {name: "Q & I"},
          seq: [],
        },
      ]
    )


    assert_equal ctx[:seq], [:authenticate, :authorize, :model, :screw_params!]

    stack_object = flow_options[:stack]
    stack = stack_object.to_a

# pp stack.to_h
    versions = stack_object.variable_versions.instance_variable_get(:@variables)
    # pp versions

    # Check if Ctx.snapshot_at works as expected.
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(stack[11], stack_object.variable_versions), # asserted snapshot is for {After(:model)}.
      {
        current_user: {value: current_user.inspect, has_changed: false},
        params:       {value: "{:name=>\"Q & I\"}", has_changed: false},
        seq:          {value: "[:authenticate, :authorize, :model]", has_changed: true},
        model:        {value: "Object", has_changed: true}
      }


    # This is a unit test we might not need anymore:
    assert_equal stack[0].task, namespace::Endpoint
    assert_snapshot versions, stack[0], current_user: 0, params: 0, seq: 0

    assert_equal stack[1].task.inspect, %(#<Trailblazer::Activity::Start semantic=:default>)
    assert_snapshot versions, stack[1], current_user: 0, params: 0, seq: 0
    assert_equal stack[2].task.inspect, %(#<Trailblazer::Activity::Start semantic=:default>)
    assert_snapshot versions, stack[2], current_user: 0, params: 0, seq: 0

    # Endpoint #authenticate
    assert_equal stack[3].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=authenticate>)
    assert_snapshot versions, stack[3], current_user: 0, params: 0, seq: 0
    assert_equal stack[4].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=authenticate>)
    assert_snapshot versions, stack[4], current_user: 0, params: 0, seq: 1

    # Endpoint #authorize
    assert_equal stack[5].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=authorize>)
    assert_snapshot versions, stack[5], current_user: 1, params: 0, seq: 1
    assert_equal stack[6].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=authorize>)
    assert_snapshot versions, stack[6], current_user: 0, params: 0, seq: 2

    # Create {in}
    assert_equal stack[7].task, namespace::Endpoint::Create
    assert_snapshot versions, stack[7], current_user: 0, params: 0, seq: 2

      # Create :model
      assert_equal stack[10].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=model>)
      assert_snapshot versions, stack[10], current_user: 0, params: 0, seq: 2
      assert_equal stack[11].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=model>)
      assert_snapshot versions, stack[11], current_user: 0, params: 0, seq: 3, model: 0

      # Create :screw_params!
      assert_equal stack[12].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=screw_params!>)
      assert_snapshot versions, stack[12], current_user: 0, params: 0, seq: 3, model: 0
      assert_equal stack[13].task.inspect, %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=screw_params!>)
      assert_snapshot versions, stack[13], current_user: 0, params: 1, seq: 4, model: 0

      # Create End.success
      assert_equal stack[15].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
      assert_snapshot versions, stack[15], current_user: 0, params: 1, seq: 4, model: 0

    # Create {out}
    assert_equal stack[16].task, namespace::Endpoint::Create
    assert_snapshot versions, stack[16], current_user: 0, params: 1, seq: 4, model: 0

    # Endpoint End.success
    assert_equal stack[17].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_snapshot versions, stack[17], current_user: 0, params: 1, seq: 4, model: 0
    assert_equal stack[18].task.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_snapshot versions, stack[18], current_user: 0, params: 1, seq: 4, model: 0
  end

  def assert_snapshot(versions, snapshot, **expected_variable_names_to_expected_index)
    captured_refs = snapshot.data[:ctx_variable_changeset] # [[variable_name, hash]]

    assert_equal captured_refs.collect { |name, hash| name }, expected_variable_names_to_expected_index.keys

    expected_variable_names_to_expected_index.each do |variable_name, index|
      assert_equal versions.fetch(variable_name).keys[index], captured_refs.find { |name, hash| name == variable_name }[1], # both hashs have to be identical
        "hash mismatch for `#{variable_name}`"
    end
  end

  it "snapshot works with {nil} values" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      pass :override
      step :create

      def override(ctx, **)
        ctx[:model] = nil
      end

      def create(ctx, **)
        ctx[:model] = Object
      end
    end

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{}, {}])

    nodes = stack.to_a

    # :override/after
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(nodes[4], stack.variable_versions),
      {
        model: {value: "nil", has_changed: true},
      }

    # :create/after
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(nodes[6], stack.variable_versions),
      {
        model: {value: "Object", has_changed: true},
      }
  end

  it "{:value_snapshooter} allows injecting new matcher/inspect tuple" do
    value_snapshooter = Trailblazer::Developer::Trace::Snapshot::Value.build
    value_snapshooter.instance_variable_get(:@matchers).unshift [ # TODO: public interface.
      ->(name, value, ctx:) { value.is_a?(Module) },
      ->(name, value, ctx:) { "Module class" }
    ]

    activity = Class.new(Trailblazer::Activity::Railway) do
      step :create

      def create(ctx, **)
        ctx[:model] = Module
      end
    end

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{params: {}},
      {
        value_snapshooter: value_snapshooter
      }
    ])

    nodes = stack.to_a

    # Op/after
    # :params is params.inspect
    # :model was serialized with custom inspector.
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(nodes[7], stack.variable_versions),
      {
        :params=>{:value=>"{}", :has_changed=>false},
        :model=>{:value=>"Module class", :has_changed=>false}
      }


  # We can also set it via {Trace.value_snapshooter}
    Trailblazer::Developer::Trace.instance_variable_set(:@value_snapshooter, value_snapshooter)

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{params: {}}, {}])

    nodes = stack.to_a

    # Op/after
    # :params is params.inspect
    # :model was serialized with custom inspector.
    assert_equal Trailblazer::Developer::Trace::Snapshot::Ctx.snapshot_ctx_for(nodes[7], stack.variable_versions),
      {
        :params=>{:value=>"{}", :has_changed=>false},
        :model=>{:value=>"Module class", :has_changed=>false}
      }

    Trailblazer::Developer::Trace.instance_variable_set(:@value_snapshooter, Trailblazer::Developer::Trace::Snapshot::Value.build) # reset to original value.
  end

  it "allows to inject custom :data_collector" do
    input_collector = ->(wrap_config, ((ctx, _), _)) { [{ ctx: ctx, something: :else }, {}] }
    output_collector = ->(wrap_config, ((ctx, _), _)) { [{ ctx: ctx, signal: wrap_config[:return_signal] }, {}] }

    stack, signal, (ctx, _) = Dev::Trace.invoke(
      flat_activity,
      [
        { seq: [] },
        {
          before_snapshooter: input_collector,
          after_snapshooter: output_collector,
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
      task = debugger_node.captured_node.snapshot_before.task

      id_label = debugger_node.label

      if task.is_a? Method
        task = "#<Method: Trailblazer::Activity::Testing::Assertions::Implementing.#{task.name}>"
      end
      [
        debugger_node.level,
        %{#{debugger_node.level}/#{task}/#{debugger_node.captured_node.snapshot_after.data[:signal]}/#{id_label}/#{color}}
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

  class IncompleteTreeTest < Minitest::Spec
    it "what" do
      activity = Class.new(Trailblazer::Activity::Railway) do
        def self.rescue((ctx, flow_options), runner:, **circuit_options)
          begin
            signal, (ctx, flow_options) = runner.(Validate, [ctx, flow_options], runner: runner, **circuit_options)
          rescue

          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end

        step task: method(:rescue)


        class Validate < Trailblazer::Activity::Railway
          step :validate
          def validate(ctx, validate: false, seq:, **)
            seq << :validate
            raise unless validate
            validate
          end
        end
      end

      # TODO: test multiple successive incomplete tasks.
      #            exception style where at some point all ascendants are incomplete.

      ctx = {validate: false}
      stack, _ = Trailblazer::Developer::Trace.invoke(activity, [ctx, {}])

      pp stack

      pp Dev::Trace.Tree(stack.to_a)
    end
  end
end
