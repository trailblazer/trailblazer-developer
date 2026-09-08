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
      class Node < Struct.new(:level, :id, :snapshot_before, :snapshot_after)
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
            remaining_captures = remaining_snapshots.to_a

            capture, snapshot = remaining_captures[0]

            raise if capture.delimits # meaning "this is an After" # DISCUSS: remove assertion?

            node, new_instructions = node_and_instructions_for(remaining_captures[0], remaining_captures[1..-1], level: level)
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
        def self.node_and_instructions_for((current_capture, current_snapshot), descendants, level:)
          # Find closing snapshot for this branch.
          # DISCUSS: "after" here implies "delimiting, the pendant of the embracing sandwich"
          capture_after, snapshot_after = descendants.find do |(capture, snapshot)|
            capture.delimits == current_capture
          end

          if snapshot_after
            snapshot_after_index = descendants.index([capture_after, snapshot_after])

            instructions =
              if snapshot_after_index == 0 # E.g. before/Start, after/Start
                [
                  [level, descendants[1..-1]]
                ]
              else
                [
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

            node = new(level, current_capture.id, current_snapshot, snapshot_after)
          else # incomplete
            raise
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
