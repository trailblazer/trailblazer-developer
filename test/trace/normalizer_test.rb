require "test_helper"

class TraceNormalizerTest < Minitest::Spec
  it "add_normalizer_step!" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b
      include T.def_steps(:a, :b)
    end

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(activity, [{seq: []}, {}])

  #@ particular nodes need a special {runtime_id}
    change_compile_id = ->(ctx, captured_node:, activity:, compile_id:, **) do
      return compile_id unless compile_id == :b

      ctx[:compile_id] = compile_id.to_s*9
    end

    original_pipelines = Trailblazer::Developer::Trace::Debugger::Normalizer::PIPELINES.clone

    Trailblazer::Developer::Trace::Debugger.add_normalizer_step!(
      change_compile_id,
      id:     "My.runtime_id",
      append: :compile_id, #@ we can change how compile_path and runtime_id are computed.
    )

    debugger_nodes = Trailblazer::Developer::Trace::Debugger::Node.build_for_stack(
      stack)

    #@ only {:b} got changed, but all of its IDs.
    assert_equal debugger_nodes.to_a[2][:compile_id], :a
    assert_equal debugger_nodes.to_a[3][:compile_id], "bbbbbbbbb"
    assert_equal debugger_nodes.to_a[3][:runtime_id], "bbbbbbbbb"

    # I hate global state.
    Trailblazer::Developer::Trace::Debugger::Normalizer::PIPELINES = original_pipelines
  end
end
