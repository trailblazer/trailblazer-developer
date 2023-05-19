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
      local_present_options = {}

      stack = Trace::Stack.new # unfortunately, we need this mutable object before things break.
      raise_exception = false

      begin
        complete_stack, signal, (ctx, flow_options) = Trace.invoke(
          activity,
          [ctx, flow_options.merge(stack: stack)],
          **circuit_options
        )
      rescue
        raise_exception = $! # TODO: will this show the very same stacktrace?

        complete_stack, exception_source = Exception.complete_stack_for_exception(stack, $!)

        local_present_options = {
          # we can hand in options per node, identified by their captured_input part.
          node_options: {
            exception_source => {data: {exception_source: true}}, # goes to {Debugger::Node.build}
          },
          style: {exception_source => [:red, :bold]},
        }
      end

      # always render the trace.
      output, returned_args = Trace::Present.(
        complete_stack,
        renderer:   Wtf::Renderer,
        color_map:  Wtf::Renderer::DEFAULT_COLOR_MAP.merge(flow_options[:color_map] || {}),
        activity:   activity,
        **local_present_options,
        **present_options,
      )

      puts output

      raise raise_exception if raise_exception
      return signal, [ctx, flow_options], circuit_options, output, returned_args
    end

    module Exception
      # When an exception occurs the Stack instance is incomplete - it is missing Snapshot::After instances
      # for Inputs still open. This method adds the missing elements so the Trace::Tree algorithm doesn't crash.
      module Stack
        def self.complete(incomplete_stack)
          processed = []

          incomplete_stack.to_a.each do |captured|
            if captured.is_a?(Trace::Snapshot::Before)
              processed << captured
            else
              processed.pop
            end
          end

          missing_captured = processed.reverse.collect { |captured| Trace::Snapshot::After.new(captured.task, captured.activity, {}) }

          Trace::Stack.new(incomplete_stack.to_a + missing_captured)
        end
      end # Stack

      def self.complete_stack_for_exception(incomplete_stack, exception)
        # in 99%, exception_source is a {Snapshot::Before}.
        exception_source = incomplete_stack.to_a.last  # DISCUSS: in most cases, this is where the problem has happened.
                                                  #   However, what if an error happens in, say, an input filter? TODO: test this

        complete_stack = Stack.complete(incomplete_stack)

        return complete_stack, exception_source
      end
    end
  end
end
