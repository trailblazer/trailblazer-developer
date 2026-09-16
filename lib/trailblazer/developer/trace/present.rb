require "hirb"

module Trailblazer::Developer
  module Trace
    module Present # DISCUSS: rename to Debugger?
      module_function

      # @private
      def default_renderer(trace_node:, **)
        [trace_node.level, trace_node.id]
      end

      # whatever we return from {:render_method} is available as {returned_args}
      # Returns the console output string.
      # @private
      def render(trace:, renderer: method(:default_renderer), **options_for_renderer)
        nodes = trace.to_a.collect do |trace_node|
          renderer.(trace_node: trace_node, trace: trace, **options_for_renderer)
        end

        Tree.render(nodes)
      end

      # Entry point for rendering a {Trace::Stack}.
      # Used in `#wtf?`.
      def call(stack, render_method: method(:render), **options, &block)
        # Build a generic array of {Trace::Node}s.
        trace_nodes = Trace.build_nodes(stack.to_a)

        return render_method.(trace: trace_nodes)
      end

      # "it's only gonna be 25 mins. 2 days later, *rummages for graph theory book*"
      # This is replacing hirb's Tree.
      module Tree
        module_function

        # count nodes in this branch.
        def offspring(current_level, string, index, nodes)
          remaining = nodes[index + 1..-1]

          index_of_delimiter = remaining.find_index { |(level, string)| level <= current_level } # we only want to find greater indexes, which is offsprings.

          if index_of_delimiter.nil?
            remaining
          elsif index_of_delimiter == 0
            []
          else
            remaining[0..index_of_delimiter - 1]
          end
        end

        def children_count(current_level, string, index, nodes)
          offspring = offspring(current_level, string, index, nodes)

          children = offspring.find_all { |(level, string)| level == current_level + 1 }

          return children.size, children
        end

        def render(nodes)
          pp nodes
          tab        = "    "
          separator  = "|   "
          branch_off = "|-- "
          terminus   = "`-- "

          draw_column_for_level = {}
          last_level = -1
# TODO: test if recursion works betta.
          lines = nodes.collect.with_index do |(level, string), i|
            # level == last_level means we're within siblings.
            #
            # those two if say "we're at the start of a new branching."
            if level > last_level # we got kids
              children_count, children = children_count(level, string, i, nodes)

              draw_column_for_level.merge!(level + 1 => [children_count > 1, children.last])
            elsif level < last_level
              children_count, children = children_count(level, string, i, nodes)

              draw_column_for_level.merge!(level + 1 => [children_count > 1, children.last])
              # DISCUSS: delete deeper levels?
              # puts "@@@@@ #{string.inspect} got family: #{children_count}"
            end

            if i == nodes.size - 1 # last line
              draw_column_for_level = Hash.new([false, [level, string]])
            end

            last_level = level

            # puts ">>> #{i} #{string} #{draw_column_for_level.inspect}"

            line = ""
            if level > 0
              if level > 1
                line << (1..level-1).collect do |i|
                  draw_column_for_level[i][0] ? separator : tab
                end.join("")

              end

              line << (draw_column_for_level[level][1] == [level, string] ? terminus : branch_off) # FIXME: [1] is the "last child".
            end

            line << "#{string}" # TODO: allow more details etc.
          end

          lines.join("\n")
        end
      end
    end # Present
  end
end
