module Trailblazer::Developer
  module Trace
    # Datastructure representing a trace.
    class Tree
      def self.Enumerable(node)
        Enumerable::Node.new(node)
      end

      module Enumerable
        class Node
          include ::Enumerable

          def initialize(node)
            @breadth_first_nodes = self.class.nodes_for(node)
          end

          # @private
          def self.nodes_for(node)
            [node, *node.nodes.collect { |n| Node.nodes_for(n) } ].flatten
          end

          def each
            @breadth_first_nodes.each do |node|
              yield node
            end
          end
        end
      end # Enumerable

      module ParentMap
        def self.for(node)
          children_map = []
          node.nodes.each { |n| children_map += ParentMap.for(n) }#.flatten(1)

          node.nodes.collect { |n| [n, node] } + children_map
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
      # pp captured_input
      # raise

          raise unless captured_input.is_a?(Entity::Input)

      while next_captured = remaining[0]
        if next_captured.is_a?(Entity::Input)

          bla, _processed = Tree(remaining, level: level+1)
          nodes += [bla]
          processed += _processed


#{processed.collect {|n| "  #{n}" }.join("\n")}"

          remaining = remaining - processed

#{remaining.collect {|n| n }.join("\n")}"

        else # Entity::Output

          raise unless next_captured.is_a?(Entity::Output)
          raise if next_captured.activity != captured_input.activity

          node = Tree::Node.new(level, captured_input, next_captured, nodes)

          return node,
            [captured_input, *processed, next_captured] # what nodes did we process here?

        end

      end


    end
  end
end
