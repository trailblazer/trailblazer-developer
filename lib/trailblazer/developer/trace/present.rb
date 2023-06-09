require "hirb"

module Trailblazer::Developer
  module Trace
    module Present # TODO: rename to Debugger?
      module_function

      # @private
      def default_renderer(debugger_node:, **) # DISCUSS: for compatibility, should we pass {:task_node} here, too?
        [debugger_node.level, debugger_node.label]
      end

      # Returns the console output string.
      # @private
      def render(debugger_nodes, renderer: method(:default_renderer), **options_for_renderer)
        nodes = debugger_nodes.to_a.collect do |debugger_node|
          renderer.(debugger_node: debugger_node, tree: debugger_nodes, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # Entry point for rendering a {Trace::Stack}.
      # Used in `#wtf?`.
      def call(stack, render_method: method(:render), node_options: {}, **options)
        # The top activity doesn't have an ID, hence we need to compute a default label.
        # TODO: maybe we should deep-merge here.
        snapshot_before_for_top_activity = stack.to_a[0]

        top_activity_options = {
          # we can pass particular label "hints".
          snapshot_before_for_top_activity => {
            # label: %{#{snapshot_before_for_top_activity.task.superclass} (anonymous)},
            label: snapshot_before_for_top_activity.task.inspect,
          },
        }

        # Build a generic array of {Trace::Node}s.
        trace_nodes = Trace.build_nodes(stack.to_a)

        # specific rendering.
        node_options = top_activity_options.merge(node_options)

        # At this point we already decided that there is a Stack.
        debugger_trace = Debugger::Trace.build(stack, trace_nodes, node_options: node_options, **options) # currently, we agree on using a Debugger::Node list as the presentation data structure.

        return render_method.(debugger_trace, **options)
      end
    end # Present
  end
end
