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
              node_id = Activity::Introspect.Nodes(node.snapshot_before.activity, task: node.snapshot_before.task).id
              path << node_id

              node = parent
            end

            path.reverse
          end
        end

        class Node < Struct.new(:level, :snapshot_before, :snapshot_after, :nodes)
          class Incomplete < Node
          end
        end
      end # Tree

      def self.pop_from_instructions!(instructions)
        while (level, remaining_snapshots = instructions.pop)
          next if level.nil?
          next if remaining_snapshots.empty?

          return level, remaining_snapshots
        end

        false
      end

      def self.BLA(instructions)
        instructions.collect do |(level, remaining_snapshots)|
          [
            level,
            remaining_snapshots.collect { |snap| [snap.class, snap.task] }
          ]
        end
      end

      def self.process_instructions(instructions) # FIXME: mutating argument
        nodes = []

        while (level, remaining_snapshots = pop_from_instructions!(instructions))
          raise unless remaining_snapshots[0].is_a?(Snapshot::Before) # DISCUSS: remove assertion?

          node, new_instructions = node_and_instructions_for(remaining_snapshots[0], remaining_snapshots[1..-1], level: level)
          pp BLA(new_instructions)

          nodes << node

          instructions += new_instructions
        end

        return nodes
      end

      # Called per snapshot_before   "process_branch"
      # 1. Find, for snapshot_before, the matching snapshot_after in the stack
      # 2. Extract snapshots inbetween those two. These are min. 1 level deeper in!
      # 3. Run process_siblings for 2.
      def self.node_and_instructions_for(snapshot_before, descendants, level:)
        puts "********* snapshot: #{level} / #{snapshot_before.task}"
        # Find closing snapshot for this branch.
        snapshot_after = descendants.find do |snapshot|
          snapshot.is_a?(Snapshot::After) && snapshot.data[:snapshot_before] == snapshot_before
        end

        if snapshot_after
          snapshot_after_index = descendants.index(snapshot_after)

          instructions =
            if snapshot_after_index == 0 # E.g. before/Start, after/Start
              [
                [level, descendants[1..-1]]
              ]
            else
              nested_instructions = [
                # instruction to go through the remaining, behind this tuple.
                [
                  level,
                  descendants[(snapshot_after_index + 1)..-1]
                ],
                # instruction to go through all snapshots between this current tuple.
                [
                  level + 1,
                  descendants[0..snapshot_after_index - 1], # "new descendants"
                ],
              ]
            end

          node            = Tree::Node.new(level, snapshot_before, snapshot_after)
        else # incomplete
          # to_be_processed = descendants
          # new_level       = level + 1
          instructions = [[level+1, descendants]]
          node         = Tree::Node::Incomplete.new(level, snapshot_before, nil)
        end

        return node, instructions
      end

      # TODO: rename to stack::tree?
      # Builds a tree graph from a linear stack.
      # Consists of {Tree::Node} structures.
      def self.Tree(descendants, level: 0, parent: nil)
        instructions = [
          [0, descendants]
        ]

        nodes = process_instructions(instructions)
      end # Tree
    end
  end # Developer
end
