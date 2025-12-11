module Trailblazer::Developer
  module Trace
    class << self
      # Follows the interface for options-compiler.
      # @private
      def invoke_options_compiler_step(activity, options, **)
        flow_options = {
          stack:              Trace::Stack.new,
          before_snapshooter: Snapshot.method(:before_snapshooter),
          after_snapshooter:  Snapshot.method(:after_snapshooter),
          value_snapshooter:  Trace.value_snapshooter
        }

        circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.task_wrap_extensions), # FIXME: this overrides existing {:wrap_runtime}.
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

      # DISCUSS: could this be a constant?
      # @public
      def options_for_canonical_invoke # TODO: can be a constant.
        {
          adds_for_options_compiler: [
            [Trailblazer::Invoke::Options::HeuristicMerge.build(method(:invoke_options_compiler_step)), id: "developer.trace", append: nil],
          ]
        }
      end
    end

    @value_snapshooter = Trace::Snapshot::Value.build()
    singleton_class.attr_reader :value_snapshooter # NOTE: this is semi-private.

    module_function

    # @private
    def task_wrap_extensions
      TASK_WRAP_EXTENSION
    end

    # Snapshot::Before and After are a generic concept of Trace, as
    # they're the interface to Trace::Present, WTF, and Debugger.

    # It's important to understand that {flow[:stack]} is mutated by design. This is needed so
    # in case of exceptions we still have a "global" trace - unfortunately Ruby doesn't allow
    # us a better way.
    # taskWrap step to capture incoming arguments of a step.
    #
    # Note that we save the created {Snapshot::Before} in the wrap_ctx.
    def capture_args(wrap_ctx, flow_options, circuit_options)
      snapshot, new_versions = Snapshot::Before.(flow_options[:before_snapshooter], wrap_ctx, flow_options, circuit_options)

      # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
      flow_options[:stack].add!(snapshot, new_versions)

      return wrap_ctx.merge(snapshot_before: snapshot), flow_options
    end

    # taskWrap step to capture outgoing arguments from a step.
    def capture_return(wrap_ctx, flow_options, circuit_options)
      snapshot, new_versions = Snapshot::After.(flow_options[:after_snapshooter], wrap_ctx, flow_options, circuit_options)

      flow_options[:stack].add!(snapshot, new_versions)

      return wrap_ctx, flow_options
    end

    # ADDS instructions to add tracing before and after {call_task}.
    TASK_WRAP_EXTENSION = Trailblazer::Activity::TaskWrap.Extension(
      [Trace.method(:capture_args),   id: "task_wrap.capture_args",   prepend: "task_wrap.call_task"],
      [Trace.method(:capture_return), id: "task_wrap.capture_return", append: nil], # append to the very end of tW.
    )
  end
end
