require "hirb"

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      # @private
      def default_renderer(node:, label: {}, **)
        task        = node.captured_input[:task]
        activity    = node.captured_input[:activity]
        label       = label[task] || compute_label(task, activity)

        [node.level, label]
      end

      # @private
      def compute_label(task, activity)
        graph       = Trailblazer::Activity::Introspect::Graph(activity) # TODO: cache for run.
        graph_node  = graph.find { |n| n[:task] == task }

        graph_node[:id]
      end

      # Entry point for rendering a Stack as a "tree branch" the way we do it in {#wtf?}.
      def call(stack, level: 1, tree: [], renderer: method(:default_renderer), options_for_renderer: {}, **)
        tree, processed = Trace.Tree(stack.to_a) # TODO: those lines need to be extracted
        # parent_map = Trace::Tree::ParentMap.for(tree)
        enumerable_tree = Trace::Tree.Enumerable(tree)

        nodes = enumerable_tree.each_with_index.collect do |node, position|
          renderer.(node: node, position: position, tree: enumerable_tree, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # TODO: focused_nodes
          # focused_nodes = Trace::Focusable.tree_nodes_for(level, input: input, output: output, **options)
          # nodes += focused_nodes if focused_nodes.length > 0

    end
  end
end
