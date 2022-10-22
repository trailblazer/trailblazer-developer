require 'trailblazer/activity'

module Trailblazer::Developer
  module Trace

    Activity = Trailblazer::Activity

    class << self
      # Public entry point to activate tracing when running {activity}.
      def call(activity, (ctx, flow_options), **circuit_options)
        activity, (ctx, flow_options), circuit_options = Trace.arguments_for_call( activity, [ctx, flow_options], **circuit_options ) # only run once for the entire circuit!

        signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [ctx, flow_options], **circuit_options)

        return flow_options[:stack], signal, [ctx, flow_options]
      end

      alias_method :invoke, :call

      def arguments_for_call(activity, (options, original_flow_options), **original_circuit_options)
        default_flow_options = {
          stack:                  Trace::Stack.new,
          input_data_collector:   Trace.method(:default_input_data_collector),
          output_data_collector:  Trace.method(:default_output_data_collector),
        }

        flow_options = {**default_flow_options, **Hash(original_flow_options)}

        default_circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.merge_plan), # DISCUSS: this overrides existing {:wrap_runtime}.
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
    def merge_plan
      Activity::TaskWrap::Extension.new(
        {
          insert: [Activity::Adds::Insert.method(:Prepend), "task_wrap.call_task"],
          row:    Activity::TaskWrap::Pipeline.Row("task_wrap.capture_args", Trace.method(:capture_args))
        },
        {
          insert: [Activity::Adds::Insert.method(:Append)], # append to the very end of tW.
          row:    Activity::TaskWrap::Pipeline.Row("task_wrap.capture_return", Trace.method(:capture_return))
        },
      )
    end

    # It's important to understand that {flow[:stack]} is mutated by design. This is needed so
    # in case of exceptions we still have a "global" trace - unfortunately Ruby doesn't allow
    # us a better way.
    # taskWrap step to capture incoming arguments of a step.
    def capture_args(wrap_config, ((ctx, flow), circuit_options))
      original_args = [[ctx, flow], circuit_options]

      captured_input = Captured(Entity::Input, flow[:input_data_collector], wrap_config, original_args)

      flow[:stack] << captured_input

      return wrap_config, original_args
    end

    # taskWrap step to capture outgoing arguments from a step.
    def capture_return(wrap_config, ((ctx, flow), circuit_options))
      original_args = [[ctx, flow], circuit_options]

      captured_output = Captured(Entity::Output, flow[:output_data_collector], wrap_config, original_args)

      flow[:stack] << captured_output

      return wrap_config, original_args
    end

    def Captured(captured_class, data_collector, wrap_config, ((ctx, flow), circuit_options))
      captured_class.new( # either Input or Output
        wrap_config[:task],
        circuit_options[:activity],
        data_collector.call(wrap_config, [ctx, flow], circuit_options)
      ).freeze
    end

    def default_input_data_collector(wrap_config, (ctx, _), circuit_options)
      graph = Trailblazer::Activity::Introspect::Graph(circuit_options[:activity])
      task  = wrap_config[:task]
      name  = (node = graph.find { |node| node[:task] == task }) ? node[:id] : task

      { ctx: ctx, task_name: name }
    end

    def default_output_data_collector(wrap_config, (ctx, _), _)
      { ctx: ctx, signal: wrap_config[:return_signal] }
    end

    # TODO: rename Entity to Captured::Task
    Entity         = Struct.new(:task, :activity, :data)
    Entity::Input  = Class.new(Entity)
    Entity::Output = Class.new(Entity)

    class Stack
      def initialize
        @stack = []
      end

      def <<(captured)
        @stack << captured
      end

      def to_a
        @stack
      end
    end
  end
end
