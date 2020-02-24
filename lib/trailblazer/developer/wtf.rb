module Trailblazer::Developer
  module_function

  def wtf(activity, *args)
    Wtf.invoke(activity, *args)
  end

  class << self
    alias wtf? wtf
  end

  module Wtf
    module_function

    # Run {activity} with tracing enabled and inject a mutable {Stack} instance.
    # This allows to display the trace even when an exception happened
    def invoke(activity, (ctx, flow_options), *circuit_options)
      activity, (ctx, flow_options), circuit_options = Wtf.arguments_for_trace(
        activity, [ctx, flow_options], *circuit_options
      )

      _returned_stack, signal, (ctx, flow_options) = Trace.invoke(
        activity, [ctx, flow_options], *circuit_options
      )

      return signal, [ctx, flow_options], circuit_options
    ensure
      puts Trace::Present.(
        flow_options[:stack],
        renderer: Wtf::Renderer,
        color_map: Wtf::Renderer::DEFAULT_COLOR_MAP.merge( flow_options[:color_map] || {} ),
      )
    end

    def arguments_for_trace(activity, (ctx, original_flow_options), **circuit_options)
      default_flow_options = {
        # this instance gets mutated with every step. unfortunately, there is
        # no other way in Ruby to keep the trace even when an exception was thrown.
        stack: Trace::Stack.new,

        input_data_collector: method(:trace_input_data_collector),
        output_data_collector: method(:trace_output_data_collector),
      }

      # Merge default options with flow_options as an order of precedence
      flow_options = { **default_flow_options, **Hash( original_flow_options ) }

      # Normalize `focus_on` param to
      #   1. Wrap step and variable names into an array if not already
      flow_options[:focus_on] = {
        steps: Array( flow_options.dig(:focus_on, :steps) ),
        variables: Array( flow_options.dig(:focus_on, :variables) ),
      }

      return activity, [ ctx, flow_options ], circuit_options
    end

    # Overring default input and output data collectors to collect/capture
    #   1. inspect of focusable variables for given focusable step
    def trace_input_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data = Trace.default_input_data_collector(wrap_config, [ctx, flow_options], circuit_options)

      if flow_options[:focus_on][:steps].include?(data[:task_name])
        data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      end

      data
    end

    def trace_output_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data = Trace.default_output_data_collector(wrap_config, [ctx, flow_options], circuit_options)

      input = flow_options[:stack].top
      if flow_options[:focus_on][:steps].include?(input.data[:task_name])
        data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      end

      data
    end
  end
end
