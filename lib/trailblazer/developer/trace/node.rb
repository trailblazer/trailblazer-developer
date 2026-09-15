module Trailblazer
  module Developer
    module Trace
      # Build array of {Trace::Node} from a snapshots stack.
      # @private
      def self.build_nodes(stack)
        Node.segment(stack.to_a.to_a, nodes: [], level: 0)
      end

      # Datastructure representing a trace.
      class Node < Struct.new(:level, :id, :snapshot_before, :snapshot_after)
        class Incomplete < Node
        end

        def self.segment(remaining, nodes:, level:)
          return nodes unless remaining[0]

          sandwich_top, current_snapshot = remaining[0]
          sandwich_bottom, bottom_snapshot = remaining[1..-1].find { |capture, _| capture.delimits.object_id == sandwich_top.object_id }
          bottom_index = remaining.index([sandwich_bottom, bottom_snapshot])

          nodes += [new(level, sandwich_top.id, current_snapshot, bottom_snapshot)]

          current_remaining = remaining[1..(bottom_index - 1)]

          nodes = segment(current_remaining, nodes: nodes, level: level + 1)

          remaining = remaining[bottom_index+1..-1]

          nodes = segment(remaining, nodes: nodes, level: level)

          return nodes
        end
      end # Node
    end
  end # Developer
end
