# NOTE: The Graph API might get deprecated and replaced.
module Trailblazer
  module Developer
    module Introspect
      # TODO: order of step/fail/pass in Node would be cool to have

      # TODO: Remove Graph. This is only useful to render the full circuit
      # Some thoughts here:
      # * where do we need Schema.outputs? and where task.outputs?
      #
      #
      # @private This API is still under construction.
      class Graph
        def initialize(activity)
          @schema   = activity.to_h or raise
          @circuit  = @schema[:circuit]
          @map      = @circuit.to_h[:map]
          @configs  = @schema[:nodes]
        end

        def find(id = nil, &block)
          return find_by_id(id) unless block_given?

          find_with_block(&block)
        end

        # TODO: convert to {#to_a}.
        def collect(strategy: :circuit)
          @map.keys.each_with_index.collect { |task, i| yield find_with_block { |node| node.task == task }, i }
        end

        def stop_events
          @circuit.to_h[:end_events]
        end

        private

        def find_by_id(id)
          node = @configs.find { |_, _node| _node.id == id } or return
          node_for(node[1])
        end

        def find_with_block
          existing = @configs.find { |_, node| yield Node(node.task, node.id, node.outputs, node.data) } or return

          node_for(existing[1])
        end

        # Build a {Graph::Node} with outputs etc.
        def node_for(node_attributes)
          Node(
            node_attributes.task,
            node_attributes.id,
            node_attributes.outputs, # [#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>]
            outgoings_for(node_attributes),
            node_attributes.data,
          )
        end

        def Node(*args)
          Node.new(*args).freeze
        end

        Node     = Struct.new(:task, :id, :outputs, :outgoings, :data)
        Outgoing = Struct.new(:output, :task)

        def outgoings_for(node)
          outputs     = node.outputs
          connections = @map[node.task]

          connections.collect do |signal, target|
            output = outputs.find { |out| out.signal == signal }
            Outgoing.new(output, target)
          end
        end
      end

      def self.Graph(*args)
        Graph.new(*args)
      end
    end # Graph
  end
end
