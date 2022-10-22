require 'hirb'

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      def default_renderer(node:, **)
        [ node.level, %{#{node.captured_input.data[:task_name]}} ]
      end

      def call(stack, level: 1, tree: [], renderer: method(:default_renderer), **options)
        tree, processed = Dev::Trace.Tree(stack.to_a) # TODO: those lines need to be extracted
        # parent_map = Dev::Trace::Tree::ParentMap.for(tree)
        enumerable_tree = Dev::Trace::Tree.Enumerable(tree)

        nodes = enumerable_tree.each_with_index.collect do |node, position|
          renderer.(node: node, position: position, tree: enumerable_tree)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # TODO: focused_nodes
          # focused_nodes = Trace::Focusable.tree_nodes_for(level, input: input, output: output, **options)
          # nodes += focused_nodes if focused_nodes.length > 0

    end
  end
end
