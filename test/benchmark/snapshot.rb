require "test_helper"
require_relative "lib/deprecated_snapshot"
require_relative "../trace_test"
require "benchmark/ips"

Snapshot = Trailblazer::Developer::Trace::Snapshot

inspect_only_flow_options = {
  before_snapshooter:   Snapshot::Deprecated.method(:default_input_data_collector),
  after_snapshooter:  Snapshot::Deprecated.method(:default_output_data_collector),
}

snapshot_flow_options = {} # added per default

Benchmark.ips do |x|
  x.report("inspect-only") do ||

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      TraceTest::Endpoint,
      [
        {seq: [], current_user: Object.new, params: {name: "Q & I"}},
        inspect_only_flow_options
      ]
    )
  end

  x.report("snapshot") do ||

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      TraceTest::Endpoint,
      [
        {seq: [], current_user: Object.new, params: {name: "Q & I"}},
        snapshot_flow_options
      ]
    )
  end

  x.compare!
end
