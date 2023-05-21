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
            [node, *node.nodes.flat_map { |n| nodes_for(n) } ]
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

        # for {snapshot_before} we're gonna build a {Node}!
        snapshot_before, remaining = stack_end[0], stack_end[1..-1]

        # raise unless snapshot_before.is_a?(Snapshot::Before)

        while next_snapshot = remaining[0]
          if next_snapshot.is_a?(Snapshot::Before)

            bla, _processed = Tree(remaining, level: level+1)
            nodes += [bla]
            processed += _processed

            remaining = remaining - processed

          else # Snapshot::After
            # DISCUSS: remove these tests?
            raise unless next_snapshot.is_a?(Snapshot::After)
            raise if next_snapshot.activity != snapshot_before.activity

            node = Tree::Node.new(level, snapshot_before, next_snapshot, nodes)

            return node,
              [snapshot_before, *processed, next_snapshot] # what nodes did we process here?
          end
        end


      end # Tree
    end
  end # Developer
end
