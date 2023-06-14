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
      local_present_options_block = ->(*) { {} }

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

        exception_source  = Exception.find_exception_source(stack, $!)
        complete_stack    = stack

        local_present_options_block = ->(trace_nodes:, **) {
          exception_source_node = trace_nodes.reverse.find do |trace_node|
            trace_node.snapshot_after == exception_source || trace_node.snapshot_before == exception_source
          end

          {
            # we can hand in options per node, identified by their captured_input part.
            node_options: {
              exception_source_node => {data: {exception_source: true}}, # goes to {Debugger::Node.build}
            },
            style: {
              exception_source_node => [:red, :bold]
            },
          }
        }
      end

      # always render the trace.
      output, returned_args = Trace::Present.(
        complete_stack,
        renderer:   Wtf::Renderer,
        color_map:  Wtf::Renderer::DEFAULT_COLOR_MAP.merge(flow_options[:color_map] || {}),
        activity:   activity,
        **present_options,
        &local_present_options_block
      )

      puts output

      raise raise_exception if raise_exception
      return signal, [ctx, flow_options], circuit_options, output, returned_args
    end

    module Exception
      def self.find_exception_source(stack, exception)
        # in 99%, exception_source is a {Snapshot::Before}.
        exception_source = stack.to_a.last  # DISCUSS: in most cases, this is where the problem has happened.
                                                  #   However, what if an error happens in, say, an input filter? TODO: test this
      end
    end
  end
end
