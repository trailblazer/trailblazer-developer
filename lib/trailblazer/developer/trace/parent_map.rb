module Trailblazer
  module Developer
    module Trace
      # Map each {Node} instance to its parent {Node}.
      module ParentMap # DISCUSS: where does this belong?
        def self.build(trace_nodes)
          levels = {}
          trace_nodes.collect do |node|
            level = node.level
            levels[level] = node

            [node, levels[level - 1]]
          end.to_h
        end

        # @public
        def self.path_for(parent_map, node)
          path = []

          while parent = parent_map[node] # DISCUSS: what if the graphs are cached and present, already?
            node_id = Activity::Introspect.Nodes(node.snapshot_before.activity, task: node.snapshot_before.task).id
            path << node_id

            node = parent
          end

          path.reverse
        end
      end # ParentMap
    end
  end # Developer
end
