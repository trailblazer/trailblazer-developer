module Trailblazer::Developer
  module Trace
    module Present # DISCUSS: rename to Debugger?
      module_function

      # @private
      def default_renderer(trace_node:, **)
        [trace_node.level, trace_node.id]
      end

      # Returns the console output string.
      # @private
      def render(trace:, renderer: method(:default_renderer), **options_for_renderer) # DISCUSS: {:options_for_renderer} is private, we actually don't need it.
        nodes = trace.to_a.collect do |trace_node|
          renderer.(trace_node: trace_node, trace: trace, **options_for_renderer)
        end

        Tree.render(nodes)
      end

      def build_trace_from_stack(lib_ctx, flow_options, signal, **) # FIXME: MOVE TO Trace::Node?
        stack = flow_options.fetch(:stack)

        segmenter = flow_options[:segmenter] || Trace::Node.method(:segmenter) # FIXME: move to options_for_trace?

        # Build a generic array of {Trace::Node}s.
        trace_nodes = Trace.build_nodes(stack.to_a, segmenter: segmenter)

        return lib_ctx, flow_options.merge(trace: trace_nodes), signal
      end

      def render_output(lib_ctx, flow_options, signal, **)
        # render_method = flow_options.fetch(:render_method)
        render_method = flow_options[:render_method] || method(:render) # FIXME: where to default this?  # FIXME: couldn't this be another step?

        # DISCUSS: rendering could happen in a separate, asyncable step.
        output = render_method.(**flow_options.to_h)

        return lib_ctx, flow_options.merge(output: output), signal
      end

      # "it's only gonna be 25 mins. 2 days later, *rummages for graph theory book*"
      # This is replacing hirb's Tree.
      module Tree
        module_function

        def normalize_graph_attributes(current, _nodes, level, index:)
          child_branches = _nodes.slice_when { |prev, curr| curr[0] == level + 1 }.to_a
          # pp child_branches#.to_a
          # [
          #   [[1, :a]],
          #   [[1, :b], [2, :d], [2, :e]],
          #   [[1, :f]]
          # ]

          leaf_child_branch = child_branches.last

          child_branches = child_branches.flat_map do |ary|
            options_for_node = ary == leaf_child_branch ? {leaf: true} : {}

            child, *nephews = ary

            [
              child + [**options_for_node, parent_i: index],
              *normalize_graph_attributes(
                child,
                nephews,
                child[0],
                index: child[2],
              )
            ]
          end

          return child_branches
        end

        def render(nodes)
          nodes_with_index = nodes.collect.with_index { |node, index| [*node, index] }

          graph_nodes = normalize_graph_attributes(nil, nodes_with_index, -1, index: nil)

          tab        = "    "
          pipe       = "|   "
          branch_off = "|-- "
          terminus   = "`-- "

          output = graph_nodes.collect do |level, string, id, options|
            leaf, parent_i = options[:leaf], options[:parent_i]

            left = ""
            if level > 0
              connector = leaf ? terminus : branch_off

              # find out for which "tab" we need a pipe |, if the parent is not leaf.
              left = (0..level - 2).to_a.collect do
                parent = graph_nodes[parent_i]
                parent_i = parent[3][:parent_i]

                parent[3][:leaf] ? tab : pipe
              end.reverse

              left << connector
              left = left.join("")
            end

            "#{left}#{string}"
          end.join("\n")

          return output
        end
      end
    end # Present
  end
end
