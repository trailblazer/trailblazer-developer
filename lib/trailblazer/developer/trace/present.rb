require 'hirb'

module Trailblazer::Developer
  module Trace
    module Present
      module_function

      def default_renderer(task_node:, **)
        [ task_node.level, %{#{task_node.value}} ]
      end

      def call(stack, level: 1, tree: [], renderer: method(:default_renderer), **options)
        tree(stack.to_a, level, tree: tree, renderer: renderer, **options)
      end

      def tree(stack, level, tree:, renderer:, **options)
        tree_for(stack, level, options.merge(tree: tree))

        nodes = tree.each_with_index.map do |task_node, position|
          renderer.(task_node: task_node, position: position, tree: tree)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      def tree_for(stack, level, tree:, **options)
        stack.each do |lvl| # always a Stack::Task[input, ..., output]
          input, output, nested = Trace::Level.input_output_nested_for_level(lvl)

          tree.push(*TreeNodes.for(level, options.merge(input: input, output: output)))

          if nested.any? # nesting
            tree_for(nested, level + 1, options.merge(tree: tree))
          end

          tree
        end
      end

      module TreeNodes
        Node = Struct.new(:level, :value, :input, :output, :options) do
          # Allow access to any custom key from options, eg. color_map
          def method_missing(name, *)
            options[name]
          end
        end

        module_function

        def for(level, input:, output:, **options)
          nodes = Array[ Node.new(level, input.data[:task_name], input, output, options).freeze ]

          focused_nodes = Trace::Focusable.tree_nodes_for(level, input: input, output: output, **options)
          nodes += focused_nodes if focused_nodes.length > 0

          nodes
        end
      end
    end
  end
end
