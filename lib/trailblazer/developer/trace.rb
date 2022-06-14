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
          stack: Trace::Stack.new,

          input_data_collector: Trace.method(:default_input_data_collector),
          output_data_collector: Trace.method(:default_output_data_collector),
        }

        flow_options = { **default_flow_options, **Hash( original_flow_options ) }

        default_circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.merge_plan), # DISCUSS: this overrides existing {:wrap_runtime}.
        }

        circuit_options = { **original_circuit_options, **default_circuit_options }

        return activity, [ options, flow_options ], circuit_options
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
      flow[:stack].indent!

      flow[:stack] << Entity::Input.new(
        wrap_config[:task],
        circuit_options[:activity],
        flow[:input_data_collector].call(wrap_config, [ctx, flow], circuit_options)
      ).freeze

      return wrap_config, [[ctx, flow], circuit_options]
    end

    # taskWrap step to capture outgoing arguments from a step.
    def capture_return(wrap_config, ((ctx, flow), circuit_options))
      flow[:stack] << Entity::Output.new(
        wrap_config[:task],
        {},
        flow[:output_data_collector].call(wrap_config, [ctx, flow], circuit_options)
      ).freeze

      flow[:stack].unindent!

      return wrap_config, [[ctx, flow], circuit_options]
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

    # Structures used in {capture_args} and {capture_return}.
    # These get pushed onto one {Level} in a {Stack}.
    #
    #   Level[
    #     Level[              ==> this is a scalar task
    #       Entity::Input
    #       Entity::Output
    #     ]
    #     Level[              ==> nested task
    #       Entity::Input
    #       Level[
    #         Entity::Input
    #         Entity::Output
    #       ]
    #       Entity::Output
    #     ]
    #   ]
    Entity         = Struct.new(:task, :activity, :data)
    Entity::Input  = Class.new(Entity)
    Entity::Output = Class.new(Entity)

    class Level < Array
      def inspect
        %{<Level>#{super}}
      end

      # @param level {Trace::Level}
      def self.input_output_nested_for_level(level)
        input  = level[0]
        output = level[-1]

        output, nested = output.is_a?(Entity::Output) ? [output, level-[input, output]] : [nil, level[1..-1]]

        return input, output, nested
      end
    end

    # Mutable/stateful per design. We want a (global) stack!
    class Stack
      attr_reader :top

      def initialize
        @nested  = Level.new
        @stack   = [ @nested ]
      end

      def indent!
        current << indented = Level.new
        @stack << indented
      end

      def unindent!
        @stack.pop
      end

      def <<(entity)
        @top = entity

        current << entity
      end

      def to_a
        @nested
      end

      private

      def current
        @stack.last
      end
    end # Stack
  end
end
