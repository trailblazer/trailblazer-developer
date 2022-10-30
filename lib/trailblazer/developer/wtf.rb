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
    def invoke(activity, (ctx, flow_options), present_options: {}, **circuit_options)
      flow_options ||= {}

      stack = Trace::Stack.new # unfortunately, we need this mutable object before things break.

      complete_stack, signal, (ctx, flow_options) = Trace.invoke(
        activity,
        [ctx, flow_options.merge(stack: stack)],
        **circuit_options
      )

      return signal, [ctx, flow_options], circuit_options

    ensure
      # incomplete_stack = flow_options[:stack]
      incomplete_stack = stack

        # in 99%, exception_source is a {Captured::Input}.
      exception_source = incomplete_stack.to_a.last  # DISCUSS: in most cases, this is where the problem has happened.
                                                #   However, what if an error happens in, say, an input filter? TODO: test this

      complete_stack = Exception::Stack.complete(incomplete_stack) # TODO: only in case of exception!

      puts Trace::Present.(
        complete_stack,
        # we can hand in options per node, identified by their captured_input part.
        node_options: {
          exception_source => {data: {exception_source: true}}, # goes to {Debugger::Node.build}
        },

        renderer:   Wtf::Renderer,
        color_map:  Wtf::Renderer::DEFAULT_COLOR_MAP.merge( flow_options[:color_map] || {} ),
        style: {exception_source => [:red, :bold]},
        **present_options, # TODO: test.
      )
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
