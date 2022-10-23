require "hirb"

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      # @private
      def default_renderer(task_node:, label: {}, **)
        task        = task_node.captured_input[:task]
        activity    = task_node.captured_input[:activity]
        label       = label[task] || compute_label(task, activity)

        [task_node.level, label]
      end

      # @private
      def compute_label(task, activity)
        graph       = Trailblazer::Activity::Introspect::Graph(activity) # TODO: cache for run.
        graph_node  = graph.find { |n| n[:task] == task }

        graph_node[:id]
      end

      # Entry point for rendering a Stack as a "tree branch" the way we do it in {#wtf?}.
      def call(stack, level: 1, renderer: method(:default_renderer), options_for_renderer: {}, **)
        enumerable_tree = build_tree(stack)

        render(enumerable_tree, renderer: renderer, **options_for_renderer)
      end

      def build_tree(stack)
        tree, processed = Trace.Tree(stack.to_a) # TODO: those lines need to be extracted
        # parent_map = Trace::Tree::ParentMap.for(tree)
        Trace::Tree.Enumerable(tree)
      end

      # Returns the console output string.
      # @private
      def render(enumerable_tree, renderer:, **options_for_renderer, &block)
        nodes = enumerable_tree.each_with_index.collect do |node, position|
          renderer.(task_node: node, tree: enumerable_tree, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # TODO: focused_nodes
          # focused_nodes = Trace::Focusable.tree_nodes_for(level, input: input, output: output, **options)
          # nodes += focused_nodes if focused_nodes.length > 0

    end
  end
end
