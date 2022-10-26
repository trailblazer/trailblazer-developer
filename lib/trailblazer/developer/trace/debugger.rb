module Trailblazer
  module Developer
    module Trace
      module Debugger
        class Node
          def initialize(captured_node:, compile_id:, runtime_id:, activity:, task:, compile_path:, runtime_path:, **)
            @captured_node  = captured_node
            @activity       = activity
            @task           = task
            @compile_id     = compile_id
            @runtime_id     = runtime_id
            @compile_path   = compile_path
            @runtime_path   = runtime_path

            # class, "type", default_label
          end

          attr_reader :task, :compile_path, :compile_id, :runtime_path, :runtime_id


          def self.default_compute_runtime_id(compile_id:, captured_node:, activity:, task:, graph:, **)
            compile_id
          end

          def self.runtime_path(runtime_id:, compile_path:, **)
            compile_path[0..-2] + [runtime_id]
          end

          def self.build(tree, enumerable_tree, compute_runtime_id: method(:default_compute_runtime_id))
            parent_map = Trace::Tree::ParentMap.build(tree).to_h # DISCUSS: can we use {enumerable_tree} for {ParentMap}?

            # DISCUSS: this might change if we introduce a new Node type for Trace.
            debugger_nodes = enumerable_tree[1..-1].collect do |node|
              activity = node.captured_input.activity
              task = node.captured_input.task

              graph_for_activity = Activity::Introspect.Graph(activity)



              Debugger::Node.new(
                captured_node: node,
                activity: activity,
                task: task,

                compile_id:   compile_id = graph_for_activity.find { |_n| _n.task == task }.id,
                compile_path: compile_path = Trace::Tree::ParentMap.path_for(parent_map, node),
                runtime_id:   runtime_id = compute_runtime_id.(compile_id: compile_id, captured_node: node, activity: activity, task: task, graph: graph_for_activity),  # FIXME: args may vary
                runtime_path: runtime_path(compile_id: compile_id, runtime_id: runtime_id, compile_path: compile_path),
              )
            end

            # TODO: add root node

          end
        end
      end # Debugger
    end # Trace
  end
end
