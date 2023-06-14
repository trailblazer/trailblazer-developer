module Trailblazer
  module Developer
    module Trace
      # Build array of {Trace::Node} from a snapshots stack.
      # @private
      def self.build_nodes(snapshots)
        instructions = [
          [0, snapshots]
        ]

        _nodes = Node.process_instructions(instructions)
      end

      # Datastructure representing a trace.
      class Node < Struct.new(:level, :task, :snapshot_before, :snapshot_after)
        class Incomplete < Node
        end

        def self.pop_from_instructions!(instructions)
          while (level, remaining_snapshots = instructions.pop)
            next if level.nil?
            next if remaining_snapshots.empty?

            return level, remaining_snapshots
          end

          false
        end

        # def self.BLA(instructions)
        #   instructions.collect do |(level, remaining_snapshots)|
        #     [
        #       level,
        #       remaining_snapshots.collect { |snap| [snap.class, snap.task] }
        #     ]
        #   end
        # end

        def self.process_instructions(instructions) # FIXME: mutating argument
          nodes = []

          while (level, remaining_snapshots = pop_from_instructions!(instructions))
            raise unless remaining_snapshots[0].is_a?(Snapshot::Before) # DISCUSS: remove assertion?

            node, new_instructions = node_and_instructions_for(remaining_snapshots[0], remaining_snapshots[1..-1], level: level)
            # pp BLA(new_instructions)

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

            node = new(level, snapshot_before.task, snapshot_before, snapshot_after)
          else # incomplete
            instructions = [
              [level + 1, descendants]
            ]

            node = Incomplete.new(level, snapshot_before.task, snapshot_before, nil)
          end

          return node, instructions
        end
      end # Node
    end
  end # Developer
end
