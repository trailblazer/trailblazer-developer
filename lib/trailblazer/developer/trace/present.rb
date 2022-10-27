require "hirb"

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      # @private
      def default_renderer(debugger_node:, label: {}, **) # DISCUSS: for compatibility, should we pass {:task_node} here, too?
        label = debugger_node.runtime_id

        [debugger_node.level, label]
      end

      # Entry point for rendering a Stack as a "tree branch" the way we do it in {#wtf?}.
      def call(stack, renderer: method(:default_renderer), **options_for_renderer)
        enumerable_tree = Debugger::Node.build_for_stack(stack) # currently, we agree on using a Debugger::Node list as the presentation data structure.

        render(enumerable_tree, renderer: renderer, **options_for_renderer)
      end

      # Returns the console output string.
      # @private
      def render(enumerable_tree, renderer:, **options_for_renderer, &block)
        nodes = enumerable_tree.collect do |debugger_node|
          renderer.(debugger_node: debugger_node, tree: enumerable_tree, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end


    end
  end
end
