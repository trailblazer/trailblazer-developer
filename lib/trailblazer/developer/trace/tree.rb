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
            puts node.captured_input.inspect
            [node, *node.nodes.collect { |n| Node.nodes_for(n) } ].flatten
          end

          def each
            @breadth_first_nodes.each do |node|
              yield node
            end
          end
        end
      end

    end # Tree

    Node = Struct.new(:level, :nodes, :captured_input, :captured_output)

    # Builds a tree graph from a linear stack.
    # Consists of {Tree::Node} structures.
    def self.Tree(stack_end, level: 0)
      processed = []
      nodes     = []


      # for {captured_input} we're gonna build a {Node}!
      captured_input, remaining = stack_end[0], stack_end[1..-1]
      # pp captured_input
      # raise

          raise unless captured_input.is_a?(Entity::Input)
# puts "#{".."*level}CAPTURED #{captured_input.task.inspect} < #{captured_input.activity.inspect}"

      while next_captured = remaining[0]
# puts "#{".."*level}remaining: #{remaining.size}"
# puts
        if next_captured.is_a?(Entity::Input)
          puts "          >"

          bla, _processed = Tree(remaining, level: level+1)
          nodes += [bla]
          processed += _processed


# puts "#{".."*level} after Tree processed:
#{processed.collect {|n| "  #{n}" }.join("\n")}"

          remaining = remaining - processed

# puts "#{".."*level}remaining:
#{remaining.collect {|n| n }.join("\n")}"

        else # Entity::Output

# puts "#{".."*level}OUTPUT #{next_captured.inspect}"
          raise unless next_captured.is_a?(Entity::Output)
          raise if next_captured.activity != captured_input.activity

# puts "#{".."*level}Node processed:  #{ processed.any? ? processed.collect {|n| n.task}.join("\n") : "NONE!"}"


          return Node.new(level, nodes, captured_input, next_captured), [captured_input, *processed, next_captured]
        end

      end


    end
  end
end
