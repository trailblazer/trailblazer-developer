require "test_helper"

class TraceNormalizerTest < Minitest::Spec
  it "add_normalizer_step!" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b
      include T.def_steps(:a, :b)
    end

    ctx, flow_options, signal = kernel.__(
      activity,
      {seq: []},
      **Trailblazer::Developer::Trace.options_for_canonical_invoke
    )

    stack = flow_options[:stack]

  #@ particular nodes need a special {runtime_id}
    change_compile_id = ->(ctx, flow_options, _, trace_node:, activity:, compile_id:, **) do
      return ctx, flow_options unless compile_id == :b

      ctx = ctx.merge(compile_id: compile_id.to_s*9)
      return ctx, flow_options
    end

    original_pipelines = Trailblazer::Developer::Debugger::Normalizer::PIPELINES.clone

    Trailblazer::Developer::Debugger.add_normalizer_step!(
      change_compile_id,
      id:     "My.runtime_id",
      append: :compile_id, #@ we can change how compile_path and runtime_id are computed.
    )

    debugger_nodes = Trailblazer::Developer::Debugger::Trace.build(
      stack, Dev::Trace.build_nodes(stack.to_a))

    #@ only {:b} got changed, but all of its IDs.
    assert_equal debugger_nodes.to_a[2][:compile_id], :a
    assert_equal debugger_nodes.to_a[3][:compile_id], "bbbbbbbbb"
    assert_equal debugger_nodes.to_a[3][:runtime_id], "bbbbbbbbb"

    # I hate global state.
    Trailblazer::Developer::Debugger::Normalizer::PIPELINES = original_pipelines
  end
end
