module Trailblazer
  module Developer
    module Trace
      class << self
        # Follows the interface for options-compiler.
        # @private
        def invoke_options_compiler_step(activity, options, **)
          flow_options = {
            stack:              Trace::Stack.new,
            value_snapshooter:  Trace.value_snapshooter
          }

          circuit_options = {
            # FIXME
            # wrap_runtime:  ::Hash.new(Trace.task_wrap_extensions), # FIXME: this overrides existing {:wrap_runtime}.
          }

          # those will be deep_merged in invoke's options-compiler?
          {
            flow_options:     flow_options,
            circuit_options:  circuit_options
          }
        end

        # Public entry point to run an activity with tracing.
        # It returns the accumulated stack of Snapshots, along with the original return values.
        # Note that {Trace.invoke} does not do any rendering.
      end

      @value_snapshooter = Trace::Snapshot::Value.build()
      singleton_class.attr_reader :value_snapshooter # NOTE: this is semi-private.

      # {delimits: nil} means we're a Before.
      class Capture < Struct.new(:id, :delimits)
        # Created at runtime by WrapRuntime.
        def call(lib_ctx, flow_options, signal, **options) # DISCUSS: do we need to default snapshot_before? with canonical invoke?
          snapshot, new_versions = Snapshot.build(lib_ctx, flow_options, signal, **options, id: id, delimits: delimits) # FIXME: circuit_options??

          # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
          flow_options[:stack].add!(self, snapshot, new_versions)

          return lib_ctx, flow_options, signal
        end
      end

      # FIXME: extract this.
      class Extension # TODO: use canonical Node::Extension or whatever we name it?!
        # Called through WrapRuntime::Runner, obviously at runtime.
        def self.call(id:, **)
          # produce ADDs
          [
            [:"task_wrap.capture_args",   Circuit::Node[capture_before = Capture.new(id), Circuit::Task::Adapter::LibInterface],   :before, :"task_wrap.call_task"],
            [:"task_wrap.capture_return", Circuit::Node[Capture.new(id, capture_before), Circuit::Task::Adapter::LibInterface], :after, nil], # append to the very end of tW.
          ]
        end

      end
    end # Trace
  end
end

