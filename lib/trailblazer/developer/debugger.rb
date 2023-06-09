module Trailblazer
  module Developer
    # Code in Debugger is only executed if the user wants to render the stack.
    module Debugger
      ATTRS = [
        :id,
        :trace_node,
        :task,
        :activity,
        :compile_id,
        :runtime_id,
        :label,
        :data,
        :snapshot_before,
        :snapshot_after,
        :level,
        :incomplete?,
        :captured_node, # TODO: remove once macro is 2.2
      ]

      # The {Debugger::Node} is an abstraction between Trace::Node and the actual rendering layer (why?)
      #
      # TODO: class, "type",
      # which track, return signal, etc
      class Node < Struct.new(*ATTRS, keyword_init: true)
        # we always key options for specific nodes by Stack::Captured::Input, so we don't confuse activities if they were called multiple times.
        #
        # @return [Debugger::Node] array of Debugger::Node
        def self.build(trace_nodes, node_options: {}, normalizer: Debugger::Normalizer::PIPELINES.last, **options_for_nodes)
          # DISCUSS: this might change if we introduce a new Node type for Trace.
          _debugger_nodes = trace_nodes.collect do |trace_node|
            # it's possible to pass per-node options, like {label: "Yo!"} via {:node_options[<snapshot_before>]}
            options_from_user  = node_options[trace_node.snapshot_before] || {} # FIXME: why not use Trace::Node to identify?

            options_from_trace_node = trace_node
              .to_h # :level, :snapshot_before, :snapshot_after
              .merge(
                id:           trace_node.object_id,
                trace_node:   trace_node,
                activity:     trace_node.snapshot_before.activity,
                task:         trace_node.snapshot_before.task,
                captured_node: DeprecatedCapturedNode, # TODO: remove once macro is 2.2
              )

            options_for_debugger_node, _ = normalizer.(
              {
                **options_from_trace_node,
                **options_from_user
              },
              []
            )

            # these attributes are not changing with the presentation
            Debugger::Node.new(**options_for_debugger_node).freeze
          end
        end

        # TODO: remove once macro is 2.2
        class DeprecatedCapturedNode
          def self.method_missing(*)
            raise "[Trailblazer] The `:captured_node` argument is deprecated, please upgrade to `trailblazer-developer-0.1.0` and use `:trace_node` if the upgrade doesn't fix it."
          end
        end
      end # Node

      # Interface for data (nodes, versions, etc) between tracing code and presentation layer.
      # We have no concept of {Stack} here anymore. Nodes and arbitrary objects such as "versions".
      # Debugger::Trace interface abstracts away the fact we have two snapshots. Here,
      # we only have a node per task.
      #
      class Trace
        # Called in {Trace::Present}.
        # Design note: goal here is to have as little computation as possible.
        def self.build(stack, trace_nodes, **options_for_debugger_nodes)
          nodes = Debugger::Node.build(
            trace_nodes,
            **options_for_debugger_nodes,
          )

          new(nodes: nodes, variable_versions: stack.variable_versions) # after this, the concept of "Stack" doesn't exist anymore.
        end

        def initialize(nodes:, variable_versions:)
          @options = {nodes: nodes, variable_versions: variable_versions}
        end

        def to_h
          @options
        end

        def to_a
          to_h[:nodes].to_a
        end
      end
    end # Debugger
  end
end
