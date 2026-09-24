module Trailblazer
  module Developer
    module Trace
      @value_snapshooter = Trace::Snapshot::Value.build()
      singleton_class.attr_reader :value_snapshooter # NOTE: this is semi-private.

      # {delimits: nil} means we're a Before.
      # FIXME: two Capture instances referring to "task_wrap.call_task" will use the same Hash key. test that explicitly.
      class Capture < Struct.new(:id, :delimits, :internal_id)
        # Created at runtime by WrapRuntime.
        def call(lib_ctx, flow_options, signal, **options) # DISCUSS: do we need to default snapshot_before? with canonical invoke?
          snapshot, new_versions = Snapshot.build(lib_ctx, flow_options, signal, **options, id: id, delimits: delimits)

          # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
          flow_options[:stack].add!(self, snapshot, new_versions)

          return lib_ctx, flow_options, signal
        end
      end

      # FIXME: extract this.
      class Extension # TODO: use canonical Node::Extension or whatever we name it?!
        # Called through WrapRuntime::Runner, obviously at runtime.
        def self.call(id:, **)
          traced_id = id.wrapped_id # {id} is a NodeWrap::Id instance.

          # produce ADDs
          [
            [:"task_wrap.capture_args",   Circuit::Node[capture_before = Capture.new(traced_id, nil, rand), Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}],   :before, :"task_wrap.call_task"],
            [:"task_wrap.capture_return", Circuit::Node[Capture.new(traced_id, capture_before), Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :after, nil], # append to the very end of tW.
          ]
        end

      end

      module Invoke
        def self.add_options_for_trace(lib_ctx, flow_options, circuit_options, **)
          extensions = circuit_options.fetch(:extensions)

          trace_extension = Circuit::WrapRuntime.Extension(adds: Developer::Trace::Extension) # WrapRuntime::Extension means we adds

          extensions = extensions + [trace_extension]

          flow_options_for_trace = {
            stack:              Trailblazer::Developer::Trace::Stack.new,
            value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
          }

          flow_options = flow_options_for_trace.merge(flow_options)

          return lib_ctx, flow_options, circuit_options.merge(extensions: extensions)
        end
      end
    end # Trace
  end
end

