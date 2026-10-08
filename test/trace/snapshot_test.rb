require "test_helper"

class SnapshotTest < Minitest::Spec
  # Test custom classes without explicit {#hash} implementation.
  class User
    def initialize(id)
      @id = id
    end
  end

  require "trailblazer/operation"
  class Endpoint < Trailblazer::Operation
    class Create < Trailblazer::Operation
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
    step Subprocess(Create), id: :bla, # FIXME: :id
      In() => [:current_user, :params, :seq],
      Out() => [:model]

    def authenticate(ctx, current_user:, seq:, **)
      seq << :authenticate
    end

    def authorize(ctx, current_user:, seq:, **)
      seq << :authorize
    end
  end

  it "snapshots that are taken before and after the NodeWrap node. this means we don't see I/o logic" do
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(
      Endpoint,
      {
        target_ctx: {
          seq: [],
          current_user: current_user = User.new(1),
          params: {name: "Q & I"},
        }
      },
      extensions: [],
      id: :Endpoint,
      compiler: my_compiler_with_trace, # FIXME: passing my_compiler shouldn't be necessary.
      conditions: [Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION, ->(node:, **) { node.options[:business_step] }]
    )

    ctx = lib_ctx[:target_ctx]

    assert_equal ctx[:seq], [:authenticate, :authorize, :model, :screw_params!]

# FIXME: stack.to_a is hash, Capture => Snapshot
    stack_object = flow_options[:stack]
    stack_capture_to_snapshot = stack_object.to_a#.to_a
    snapshots = stack_capture_to_snapshot.values
    # pp snapshots[7]

# pp stack.to_h
    versions = stack_object.variable_versions.instance_variable_get(:@variables)

    # Check if Ctx.snapshot_ctx_for works as expected.
    assert_equal Trailblazer::Developer::Trace::Snapshot.snapshot_ctx_for(snapshots[7], stack_object.variable_versions), # asserted snapshot is for "after" {:model}.
      {
        current_user: {value: current_user.inspect, has_changed: false},
        params:       {value: {:name=>"Q & I"}.inspect, has_changed: false},
        seq:          {value: "[:authenticate, :authorize, :model]", has_changed: true},
        model:        {value: "Object", has_changed: true}
      }



    assert_snapshot versions, :Endpoint, snapshots[0], current_user: 0, params: 0, seq: 0

    assert_snapshot versions, :authenticate, snapshots[1], current_user: 0, params: 0, seq: 0
    assert_snapshot versions, :authenticate, snapshots[2], current_user: 0, params: 0, seq: 1

    # Since we're running the "NodeWrap" tracing, the tracing around :authorize doesn't see the Inject etc. as it's
    # tracing the entire task_wrap (in --> call_task --> out) as a single node.
    assert_snapshot versions, :authorize, snapshots[3], current_user: 0, params: 0, seq: 1
    assert_snapshot versions, :authorize, snapshots[4], current_user: 0, params: 0, seq: 2

    # TODO: test the same with Trace::TaskWrap or whatever we're gonna name it.
    # # Endpoint #authorize
    # assert_equal CU.strip(stack[5].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authorize>>>)
    # assert_snapshot versions, stack[5], current_user: 1, params: 0, seq: 1
    # assert_equal CU.strip(stack[6].task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:authorize>>>)
    # assert_snapshot versions, stack[6], current_user: 0, params: 0, seq: 2
    assert_snapshot versions, :bla, snapshots[5], current_user: 0, params: 0, seq: 2
    assert_snapshot versions, :model, snapshots[6], current_user: 0, params: 0, seq: 2
    assert_snapshot versions, :model, snapshots[7], current_user: 0, params: 0, seq: 3, model: 0

    assert_snapshot versions, :screw_params!, snapshots[8], current_user: 0, params: 0, seq: 3, model: 0
    assert_snapshot versions, :screw_params!, snapshots[9], current_user: 0, params: 1, seq: 4, model: 0

    assert_snapshot versions, :"End.success", snapshots[10], current_user: 0, params: 1, seq: 4, model: 0
    assert_snapshot versions, :"End.success", snapshots[11], current_user: 0, params: 1, seq: 4, model: 0
    assert_snapshot versions, :bla,           snapshots[12], current_user: 0, params: 1, seq: 4, model: 0
    assert_snapshot versions, :"End.success", snapshots[13], current_user: 0, params: 1, seq: 4, model: 0
    assert_snapshot versions, :"End.success", snapshots[14], current_user: 0, params: 1, seq: 4, model: 0
    assert_snapshot versions, :Endpoint,      snapshots[15], current_user: 0, params: 1, seq: 4, model: 0
  end

  it "we can also trace using TaskWrap and see what I/o does." do
    raise
  end

  def assert_snapshot(versions, expected_id, snapshot, **expected_variable_names_to_expected_index)
    assert_equal snapshot.id, expected_id

    captured_refs = snapshot.data[:ctx_variable_changeset] # [[variable_name, hash]]

    assert_equal captured_refs.collect { |name, hash| name }.sort, expected_variable_names_to_expected_index.keys.sort

    expected_variable_names_to_expected_index.each do |variable_name, index|
      assert_equal versions.fetch(variable_name).keys[index], captured_refs.find { |name, hash| name == variable_name }[1], # both hashs have to be identical
        "hash mismatch for `#{variable_name}`"
    end
  end
end
