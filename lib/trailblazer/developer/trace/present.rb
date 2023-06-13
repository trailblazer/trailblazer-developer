require "hirb"

module Trailblazer::Developer
  module Trace
    module Present # DISCUSS: rename to Debugger?
      module_function

      # @private
      def default_renderer(debugger_node:, **) # DISCUSS: for compatibility, should we pass {:task_node} here, too?
        [debugger_node.level, debugger_node.label]
      end

      # Returns the console output string.
      # @private
      def render(debugger_trace:, renderer: method(:default_renderer), **options_for_renderer)
        nodes = debugger_trace.to_a.collect do |debugger_node|
          renderer.(debugger_node: debugger_node, debugger_trace: debugger_trace, **options_for_renderer)
        end

        Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
      end

      # Entry point for rendering a {Trace::Stack}.
      # Used in `#wtf?`.
      def call(stack, render_method: method(:render), node_options: nil, **options, &block)
        raise "[Trailblazer] The `:node_options` option for `Trace::Present` is deprecated. Please use the block style as described here: #FIXME" if node_options

        # Build a generic array of {Trace::Node}s.
        trace_nodes = Trace.build_nodes(stack.to_a)

        # The top activity doesn't have an ID, hence we need to compute a default label.
        top_activity_trace_node = trace_nodes[0]

        build_options = {
          node_options: {
            # we can pass particular label "hints".
            top_activity_trace_node => {
              # label: %{#{top_activity_trace_node.task.superclass} (anonymous)},
              label: top_activity_trace_node.task.inspect,
            },
          }
        }

        build_options = build_options.merge(options) # since we only have {:node_options} in {build_options}, we can safely merge here.

        # specific rendering.
        options_from_block = block_given? ? block.call(trace_nodes: trace_nodes, stack: stack, **build_options) : {}

        build_options = merge_local_options(options_from_block, build_options)

        # currently, we agree on using a Debugger::Node list as the presentation data structure.
        debugger_trace = Debugger::Trace.build(stack, trace_nodes, **build_options)

        return render_method.(debugger_trace: debugger_trace, **build_options)
      end

      # @private
      def merge_local_options(options, local_options)
        merged_hash = options.collect do |key, value|
          [
            key,
            value.is_a?(Hash) ? local_options.fetch(key, {}).merge(value) : value # options are winning over local_options[key]
          ]
        end.to_h

        local_options.merge(merged_hash)
      end
    end # Present
  end
end
