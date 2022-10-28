require "hirb"

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      # @private
      def default_renderer(debugger_node:, **) # DISCUSS: for compatibility, should we pass {:task_node} here, too?
        [debugger_node.level, debugger_node.label]
      end

      # Entry point for rendering a Stack as a "tree branch" the way we do it in {#wtf?}.
      def call(stack, renderer: method(:default_renderer), label: {}, **options_for_renderer)
        debugger_nodes = Debugger::Node.build_for_stack(stack, label: label) # currently, we agree on using a Debugger::Node list as the presentation data structure.

        render(debugger_nodes, renderer: renderer, **options_for_renderer)
      end

      # Returns the console output string.
      # @private
      def render(debugger_nodes, renderer:, **options_for_renderer)
        nodes = debugger_nodes.collect do |debugger_node|
          renderer.(debugger_node: debugger_node, tree: debugger_nodes, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end
    end # Present
  end
end
