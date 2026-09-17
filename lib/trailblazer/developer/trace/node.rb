module Trailblazer
  module Developer
    module Trace
      # Build array of {Trace::Node} from a snapshots stack.
      # @private
      def self.build_nodes(stack, **options)
        Node.segment(stack.to_a.to_a, nodes: [], level: 0, **options)
      end

      # Datastructure representing a trace.
      class Node < Struct.new(:level, :id, :snapshot_before, :snapshot_after)
        class Incomplete < Node
          # This segmenter contains the {if} to handle when we cannot find a bottomless sandwich
          # because something raised on the path.
          #
          #0 a Incomplete
          #1   b Node
          #2   <b
          #3   c Incomplete
          #4     d! Incomplete
          def self.segmenter(sandwich_bottom, bottom_index, remaining) # DISCUSS: segmenter in Node? hm.., not really the place.
            return super unless bottom_index.nil? # we could find the sandwich bottom pendant.

            range_for_offsprings = 1..-1
            range_for_followers = remaining.size..-1 # will result in [].
            return [], range_for_offsprings, range_for_followers, Incomplete
          end
        end

        # DISCUSS: by "offspring" i refer to "my kids and their kids etc".
        def self.segmenter(sandwich_bottom, bottom_index, remaining)
          range_for_offsprings = 1..(bottom_index - 1) # our offsprings [b, c]
          range_for_followers = bottom_index + 1..-1 # what comes after us, [<e, ...]

          return sandwich_bottom, range_for_offsprings, range_for_followers, Node
        end

        # Find the first sandwich, recursively process its "filling", and then
        # process the rest behind the sandwich.
        def self.segment(remaining, nodes:, level:, node_class: Node, segmenter:)
          return nodes unless remaining[0]

          sandwich_top = remaining[0]
          top_capture, top_snapshot = sandwich_top

          sandwich_bottom = remaining[1..-1].find { |capture, _| capture.delimits.object_id == top_capture.object_id }
          bottom_index = remaining.index(sandwich_bottom)

          sandwich_bottom, range_for_offsprings, range_for_followers, node_class = segmenter.(sandwich_bottom, bottom_index, remaining)

          offspring = remaining[range_for_offsprings] # b, c, ...
          follower = remaining[range_for_followers]   # e, ...
          # <a
          #   <b
          #   </b
          #   <c
          #   </c
          # </a
          # <e
          # ...

          _, bottom_snapshot = sandwich_bottom

          nodes += [node_class.new(level, top_capture.id, top_snapshot, bottom_snapshot)]

          # go into "your" branch and process b and c
          nodes = segment(offspring, nodes: nodes, level: level + 1, segmenter: segmenter)

          # then, handle the ones behind/after this branch
          nodes = segment(follower, nodes: nodes, level: level, segmenter: segmenter)

          return nodes
        end
      end # Node
    end
  end # Developer
end
