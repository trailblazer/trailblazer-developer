module Trailblazer::Developer
  module_function

  def wtf(activity, *args, **circuit_options)
    Wtf.invoke(activity, *args, **circuit_options)
  end

  class << self
    alias wtf? wtf
  end

  module Wtf
    module_function

    # Run {activity} with tracing enabled and inject a mutable {Stack} instance.
    # This allows to display the trace even when an exception happened
    def invoke(activity, (ctx, flow_options), **circuit_options)
      # activity, (ctx, flow_options), circuit_options = Wtf.arguments_for_trace(
      activity, (ctx, flow_options), circuit_options = Trace.arguments_for_call(
        activity, [ctx, flow_options], **circuit_options
      )

      _returned_stack, signal, (ctx, flow_options) = Trace.invoke(
        activity, [ctx, flow_options], **circuit_options
      )

      return signal, [ctx, flow_options], circuit_options
    ensure


      incomplete_stack = flow_options[:stack]

      # in 99%, exception_source is a {Captured::Input}.
      exception_source = incomplete_stack.to_a.last  # DISCUSS: in most cases, this is where the problem has happened.
                                                #   However, what if an error happens in, say, an input filter? TODO: test this

      complete_stack = Exception::Stack.complete(incomplete_stack) # TODO: only in case of exception!







      puts Trace::Present.(
        complete_stack,
        # we can hand in options per node, identified by their captured_input part.
        exception_source => {data: {exception_source: true}}, # goes to {Debugger::Node.build}

        renderer:   Wtf::Renderer,
        color_map:  Wtf::Renderer::DEFAULT_COLOR_MAP.merge( flow_options[:color_map] || {} ),
        style: {exception_source => [:red, :bold]}

        # **options_for_renderer
      )

# TODO: move to trb-pro
# require "trailblazer/developer/pro"
# Pro.call( enumerable_tree, tree)
    end

    # def arguments_for_trace(activity, (ctx, original_flow_options), **circuit_options)
    #   default_flow_options = {
    #     # this instance gets mutated with every step. unfortunately, there is
    #     # no other way in Ruby to keep the trace even when an exception was thrown.
    #     stack: Trace::Stack.new,

    #     input_data_collector: method(:trace_input_data_collector),
    #     output_data_collector: method(:trace_output_data_collector),
    #   }

    #   # Merge default options with flow_options as an order of precedence
    #   flow_options = { **default_flow_options, **Hash( original_flow_options ) }

    #   # Normalize `focus_on` param to
    #   #   1. Wrap step and variable names into an array if not already
    #   flow_options[:focus_on] = {
    #     steps: Array( flow_options.dig(:focus_on, :steps) ),
    #     variables: Array( flow_options.dig(:focus_on, :variables) ),
    #   }

    #   [activity, [ ctx, flow_options ], circuit_options]
    # end

    # Overring default input and output data collectors to collect/capture
    #   1. inspect of focusable variables for given focusable step
    #   2. Or inspect of focused variables for all steps
    def trace_input_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data = Trace.default_input_data_collector(wrap_config, [ctx, flow_options], circuit_options)

      if Wtf.capture_variables?(step_name: data[:task_name], **flow_options)
        data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      end

      data
    end

    def trace_output_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data  = Trace.default_output_data_collector(wrap_config, [ctx, flow_options], circuit_options)
      # input = flow_options[:stack].top

      # if Wtf.capture_variables?(step_name: input.data[:task_name], **flow_options)
      #   data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      # end

      data
    end

    # private
    def capture_variables?(step_name:, focus_on:, **)
      return true if focus_on[:steps].include?(step_name)                 # For given step
      return true if focus_on[:steps].empty? && focus_on[:variables].any? # For selected vars but all steps

      false
    end

    module Exception
      # When an exception occurs the Stack instance is incomplete - it is missing Captured::Output instances
      # for Inputs still open. This method adds the missing elements so the Trace::Tree algorithm doesn't crash.
      module Stack
        def self.complete(incomplete_stack)
          processed = []

          incomplete_stack.to_a.each do |captured|
            if captured.is_a?(Trace::Captured::Input)
              processed << captured
            else
              processed.pop
            end
          end

          missing_captured = processed.reverse.collect { |captured| Trace::Captured::Output.new(captured.task, captured.activity, {}) }

          Trace::Stack.new(incomplete_stack.to_a + missing_captured)
        end
      end # Stack

    end
  end
end
