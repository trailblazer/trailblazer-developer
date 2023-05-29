require "hirb"

module Trailblazer::Developer
  module Trace
    module Present
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

      # Entry point for rendering a Stack as a "tree branch" the way we do it in {#wtf?}.
      def call(stack, render_method: method(:render), node_options: {}, **options)
        # The top activity doesn't have an ID, hence we need to compute a default label.
        # TODO: maybe we should deep-merge here.
        captured_input_for_top_activity = stack.to_a[0]

        top_activity_options = {
          # we can pass particular label "hints".
          captured_input_for_top_activity => {
            # label: %{#{captured_input_for_top_activity.task.superclass} (anonymous)},
            label: captured_input_for_top_activity.task.inspect,
          },
        }

        node_options = top_activity_options.merge(node_options)

        # At this point we already decided that there is a Stack. and that we will have versions of variables???????????????
        debugger_nodes = Debugger.trace_for_stack(stack, node_options: node_options, **options) # currently, we agree on using a Debugger::Node list as the presentation data structure.

        return render_method.(debugger_nodes, **options)
      end
    end # Present
  end
end
