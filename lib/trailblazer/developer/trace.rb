module Trailblazer::Developer
  module Trace
    class << self
      # Public entry point to run an activity with tracing.
      # It returns the accumulated stack of Snapshots, along with the original return values.
      # Note that {Trace.invoke} does not do any rendering.
      def call(activity, (ctx, flow_options), **circuit_options)
        activity, (ctx, flow_options), circuit_options = Trace.arguments_for_call(activity, [ctx, flow_options], **circuit_options) # only run once for the entire circuit!

        signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [ctx, flow_options], **circuit_options)

        return flow_options[:stack], signal, [ctx, flow_options]
      end

      alias_method :invoke, :call

      def arguments_for_call(activity, (options, original_flow_options), **original_circuit_options)
        default_flow_options = {
          stack:              Trace::Stack.new,
          # TODO: we can prepare static values in a HASH.
          before_snapshooter: Snapshot.method(:before_snapshooter),
          after_snapshooter:  Snapshot.method(:after_snapshooter),
          value_snapshooter: Trace.value_snapshooter
        }

        flow_options = {**default_flow_options, **Hash(original_flow_options)}

        default_circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.task_wrap_extensions), # DISCUSS: this overrides existing {:wrap_runtime}.
        }

        circuit_options = {**original_circuit_options, **default_circuit_options}

        return activity, [options, flow_options], circuit_options
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
    def capture_args(wrap_config, original_args)
      flow_options = original_args[0][1]

      snapshot, new_versions = Snapshot::Before.(flow_options[:before_snapshooter], wrap_config, original_args)

      # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
      flow_options[:stack].add!(snapshot, new_versions)

      return wrap_config.merge(snapshot_before: snapshot), original_args
    end

    # taskWrap step to capture outgoing arguments from a step.
    def capture_return(wrap_config, ((ctx, flow_options), circuit_options))
      original_args = [[ctx, flow_options], circuit_options]

      snapshot, new_versions = Snapshot::After.(flow_options[:after_snapshooter], wrap_config, original_args)

      flow_options[:stack].add!(snapshot, new_versions)

      return wrap_config, original_args
    end

    # Insertions for the trace tasks that capture the arguments just before calling the task,
    # and before the TaskWrap is finished.
    TASK_WRAP_EXTENSION = Trailblazer::Activity::TaskWrap.Extension(
      [Trace.method(:capture_args),   id: "task_wrap.capture_args",   prepend: "task_wrap.call_task"],
      [Trace.method(:capture_return), id: "task_wrap.capture_return", append: nil], # append to the very end of tW.
    )
  end
end
