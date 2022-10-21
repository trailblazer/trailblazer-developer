module Trailblazer::Developer
  module Trace
    # Datastructure representing a trace.
    class Tree

    end # Tree

    Node = Struct.new(:level, :nodes, :captured_input, :captured_output)

    def self.Tree(stack_end, level: 0)
      processed = []
      nodes     = []


      # for {captured_input} we're gonna build a {Node}!
      captured_input, remaining = stack_end[0], stack_end[1..-1]
      # pp captured_input
      # raise

          raise unless captured_input.is_a?(Entity::Input)
puts "#{".."*level}CAPTURED #{captured_input.task.inspect} < #{captured_input.activity.inspect}"

      while next_captured = remaining[0]
puts "#{".."*level}remaining: #{remaining.size}"
# puts
        if next_captured.is_a?(Entity::Input)
          puts "          >"

          bla, processed = Tree(remaining, level: level+1)
          nodes += [bla]


puts "#{".."*level} after Tree processed:
#{processed.collect {|n| "  #{n}" }.join("\n")}"

          remaining = remaining - processed

puts "#{".."*level}remaining:
#{remaining.collect {|n| n }.join("\n")}"

        else # Entity::Output

puts "#{".."*level}OUTPUT #{next_captured.inspect}"
          raise unless next_captured.is_a?(Entity::Output)
          raise if next_captured.activity != captured_input.activity

puts "#{".."*level}Node processed:  #{ processed.any? ? processed.collect {|n| n.task}.join("\n") : "NONE!"}"


          return Node.new(level, nodes, captured_input, next_captured), [captured_input, *processed, next_captured]
        end

      end


    end
  end
end
