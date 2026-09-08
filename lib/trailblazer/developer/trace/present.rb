require "hirb"

module Trailblazer::Developer
  module Trace
    module Present # DISCUSS: rename to Debugger?
      module_function

      # @private
      def default_renderer(trace_node:, **)
        [trace_node.level, trace_node.id]
      end

      # whatever we return from {:render_method} is available as {returned_args}
      # Returns the console output string.
      # @private
      def render(trace:, renderer: method(:default_renderer), **options_for_renderer)
        nodes = trace.to_a.collect do |trace_node|
          renderer.(trace_node: trace_node, trace: trace, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # Entry point for rendering a {Trace::Stack}.
      # Used in `#wtf?`.
      def call(stack, render_method: method(:render), **options, &block)
        # Build a generic array of {Trace::Node}s.
        trace_nodes = Trace.build_nodes(stack.to_a)

        return render_method.(trace: trace_nodes)
      end
    end # Present
  end
end
