module Trailblazer
  module Developer
    module Trace
      # Datastructure representing a trace.
      class Tree
        # This could also be seen as {tree.to_a}.
        def self.Enumerable(node)
          Enumerable.nodes_for(node)
        end

        module Enumerable
          # @private
          def self.nodes_for(node)
            [node, *node.nodes.collect { |n| nodes_for(n) } ].flatten
          end
        end # Enumerable

        # Map each {Node} instance to its parent {Node}.
        module ParentMap
          def self.build(node)
            children_map = []
            node.nodes.each { |n| children_map += ParentMap.build(n) }#.flatten(1)

            node.nodes.collect { |n| [n, node] } + children_map
          end

          # @public
          def self.path_for(parent_map, node)
            path = []

            while parent = parent_map[node] # DISCUSS: what if the graphs are cached and present, already?
              node_id = Activity::Introspect.Nodes(node.captured_input.activity, task: node.captured_input.task).id
              path << node_id

              node = parent
            end

            path.reverse
          end
        end

        class Node < Struct.new(:level, :captured_input, :captured_output, :nodes)
        end
      end # Tree


      # Builds a tree graph from a linear stack.
      # Consists of {Tree::Node} structures.
      def self.Tree(stack_end, level: 0, parent: nil)
        processed = []
        nodes     = []

        # for {captured_input} we're gonna build a {Node}!
        captured_input, remaining = stack_end[0], stack_end[1..-1]

            raise unless captured_input.is_a?(Snapshot::Before)

        while next_captured = remaining[0]
          if next_captured.is_a?(Snapshot::Before)

            bla, _processed = Tree(remaining, level: level+1)
            nodes += [bla]
            processed += _processed


            remaining = remaining - processed

          else # Snapshot::After

            raise unless next_captured.is_a?(Snapshot::After)
            raise if next_captured.activity != captured_input.activity

            node = Tree::Node.new(level, captured_input, next_captured, nodes)

            return node,
              [captured_input, *processed, next_captured] # what nodes did we process here?

          end

        end


      end # Tree
    end
  end # Developer
end
