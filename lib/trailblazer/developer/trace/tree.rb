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

      def self.process_siblings(remaining_snapshots, level:)
        puts "~~~~~~~~~ #{level} process_siblings #{remaining_snapshots[0].inspect}"
        nodes = []
        processed_snapshots = []

        while snapshot = remaining_snapshots[0]
          raise unless snapshot.is_a?(Snapshot::Before) # DISCUSS: remove assertion?
                                                                                                          # FIXME: hm.
          nodes_from_branch, processed_snapshots_from_branch = process_from_snapshot_before(snapshot, remaining_snapshots[1..-1], level: level)

          nodes += nodes_from_branch
          processed_snapshots += processed_snapshots_from_branch

          remaining_snapshots = remaining_snapshots - processed_snapshots
        end

        return nodes, processed_snapshots
      end

      # Called per snapshot_before   "process_branch"
      # 1. Find, for snapshot_before, the matching snapshot_after in the stack
      # 2. Extract snapshots inbetween those two. These are min. 1 level deeper in!
      # 3. Run process_siblings for 2.
      def self.process_from_snapshot_before(snapshot_before, descendants, level:)
        puts "********* snapshot: #{level} / #{snapshot_before.task}"
        # Find closing snapshot for this branch.
        snapshot_after = descendants.find do |snapshot|
          snapshot.is_a?(Snapshot::After) && snapshot.data[:snapshot_before] == snapshot_before
        end

        if snapshot_after
          snapshot_after_index = descendants.index(snapshot_after)

          to_be_processed, new_level =
            if snapshot_after_index == 0 # E.g. before/Start, after/Start
              [
                descendants[1..-1],
                level
              ]
            else
              [
                descendants[0..descendants.index(snapshot_after) - 1], # "new descendants"
                level + 1
              ]
            end

          node            = Tree::Node.new(level, snapshot_before, snapshot_after)
        else # incomplete
          to_be_processed = descendants
          new_level       = level + 1

          node            = Tree::Node::Incomplete.new(level, snapshot_before, nil)
        end

        # pp to_be_processed

        nodes, processed_snapshots = process_siblings(to_be_processed, level: new_level)

        return [node, *nodes], [snapshot_before, *processed_snapshots, snapshot_after].compact # what nodes did we process here?
      end

      # TODO: rename to stack::tree?
      # Builds a tree graph from a linear stack.
      # Consists of {Tree::Node} structures.
      def self.Tree(descendants, level: 0, parent: nil)
        # descendants.collect do |snapshot|
        #   raise snapshot.inspect
        # end

        nodes, _ = process_siblings(descendants, level: 0)
        # pp nodes





        processed = []
        nodes     = []

        # for {snapshot_before} we're gonna build a {Node}!
        snapshot_before, remaining = stack_end[0], stack_end[1..-1]

        # raise unless snapshot_before.is_a?(Snapshot::Before)

        # Every time we see a {Before} snapshot, it means a new activity/task starts,
        # and we discovered a new sub-branch.
        while next_snapshot = remaining[0]
          if next_snapshot.is_a?(Snapshot::Before)

            branch_node, _processed = Tree(remaining, level: level+1) # new branch
            nodes += [branch_node]
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

      def self.Tree_DEPRECATED_thatcanthandleincompletetrees(stack_end, level: 0, parent: nil)
        processed = []
        nodes     = []

        # for {snapshot_before} we're gonna build a {Node}!
        snapshot_before, remaining = stack_end[0], stack_end[1..-1]

        # raise unless snapshot_before.is_a?(Snapshot::Before)

        # Every time we see a {Before} snapshot, it means a new activity/task starts,
        # and we discovered a new sub-branch.
        while next_snapshot = remaining[0]
          if next_snapshot.is_a?(Snapshot::Before)

            branch_node, _processed = Tree(remaining, level: level+1) # new branch
            nodes += [branch_node]
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
      end # Tree_DEPRECATED_thatcanthandleincompletetrees
    end
  end # Developer
end
