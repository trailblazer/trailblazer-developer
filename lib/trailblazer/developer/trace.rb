module Trailblazer::Developer
  module Trace

    class << self
      # Public entry point to activate tracing when running {activity}.
      def call(activity, (ctx, flow_options), **circuit_options)
        activity, (ctx, flow_options), circuit_options = Trace.arguments_for_call( activity, [ctx, flow_options], **circuit_options ) # only run once for the entire circuit!

        signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [ctx, flow_options], **circuit_options)

        return flow_options[:stack], signal, [ctx, flow_options]
      end

      alias_method :invoke, :call

      def arguments_for_call(activity, (options, original_flow_options), **original_circuit_options)
        default_flow_options = {
          stack:              Trace::Stack.new,
          before_snapshooter: Trace::Snapshot::Deprecated.method(:default_input_data_collector),
          after_snapshooter:  Trace::Snapshot::Deprecated.method(:default_output_data_collector),
        }

        flow_options = {**default_flow_options, **Hash(original_flow_options)}

        default_circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.task_wrap_extensions), # DISCUSS: this overrides existing {:wrap_runtime}.
        }

        circuit_options = {**original_circuit_options, **default_circuit_options}

        return activity, [options, flow_options], circuit_options
      end
    end

    module_function
    # Insertions for the trace tasks that capture the arguments just before calling the task,
    # and before the TaskWrap is finished.
    #
    # @private
    def task_wrap_extensions
      Trailblazer::Activity::TaskWrap.Extension(
        [Trace.method(:capture_args),   id: "task_wrap.capture_args",   prepend: "task_wrap.call_task"],
        [Trace.method(:capture_return), id: "task_wrap.capture_return", append: nil], # append to the very end of tW.
      )
    end

    # It's important to understand that {flow[:stack]} is mutated by design. This is needed so
    # in case of exceptions we still have a "global" trace - unfortunately Ruby doesn't allow
    # us a better way.
    # taskWrap step to capture incoming arguments of a step.
    def capture_args(wrap_config, ((ctx, flow), circuit_options))
      original_args = [[ctx, flow], circuit_options]

      flow[:stack] << take_snapshot!(Snapshot::Before, flow[:before_snapshooter], wrap_config, original_args)

      return wrap_config, original_args
    end

    # taskWrap step to capture outgoing arguments from a step.
    def capture_return(wrap_config, ((ctx, flow), circuit_options))
      original_args = [[ctx, flow], circuit_options]

      flow[:stack] << take_snapshot!(Snapshot::After, flow[:after_snapshooter], wrap_config, original_args)

      return wrap_config, original_args
    end

    # TODO: return {flow_options} or at least {stack}
    def take_snapshot!(snapshot_class, snapshooter, wrap_config, original_args)
      snapshot_class.build(snapshooter, wrap_config, original_args)
    end
  end
end
