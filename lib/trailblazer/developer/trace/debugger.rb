module Trailblazer
  module Developer
    module Trace
      module Debugger
        class Node
          def initialize(captured_node:, compile_id:, runtime_id:, activity:, task:, compile_path:, runtime_path:, label:, data:, **)
            @captured_node  = captured_node
            @activity       = activity
            @task           = task
            @compile_id     = compile_id
            @runtime_id     = runtime_id
            @compile_path   = compile_path
            @runtime_path   = runtime_path
            @level          = @captured_node.level
            @label          = label
            @data           = data

            # class, "type", default_label,
            # which track, return signal, etc
          end

          attr_reader :task, :compile_path, :compile_id, :runtime_path, :runtime_id, :level, :captured_node, :label, :data


          def self.default_compute_runtime_id(compile_id:, captured_node:, activity:, task:, graph:, **)
            compile_id
          end

          def self.default_compute_label(label:, task:, runtime_id:, **)
            label = label[task] || runtime_id
          end

          def self.runtime_path(runtime_id:, compile_path:, **)
            compile_path[0..-2] + [runtime_id]
          end

          def self.data_for(captured_node:, data:, **)
            # We key by {Captured::Input}.
            data[captured_node.captured_input] || {}
          end

          def self.build(tree, enumerable_tree, compute_runtime_id: method(:default_compute_runtime_id), label: {}, data: {})
            parent_map = Trace::Tree::ParentMap.build(tree).to_h # DISCUSS: can we use {enumerable_tree} for {ParentMap}?

            # TODO: maybe allow {graph[task]}
            # TODO: cache activity graph
            top_activity = enumerable_tree[0].captured_input.task
            graph_nodes = { # TODO: any other way to grab the container_activity? Maybe by passing {activity}?
              enumerable_tree[0].captured_input.activity => [Struct.new(:id, :task).new(top_activity.inspect, top_activity)]
            }

            # DISCUSS: this might change if we introduce a new Node type for Trace.
            debugger_nodes = enumerable_tree[0..-1].collect do |node|
              activity = node.captured_input.activity
              task = node.captured_input.task


              graph_for_activity = graph_nodes[activity] || Activity::Introspect.Graph(activity)

# DISCUSS: pass down the Graph::Node?
              # these attributes are not changing with the presentation
              Debugger::Node.new(
                captured_node: node,
                activity: activity,
                task: task,

                compile_id:   compile_id = graph_for_activity.find { |_n| _n.task == task }.id,
                compile_path: compile_path = Trace::Tree::ParentMap.path_for(parent_map, node),
                runtime_id:   runtime_id = compute_runtime_id.(compile_id: compile_id, captured_node: node, activity: activity, task: task, graph: graph_for_activity),  # FIXME: args may vary
                runtime_path: runtime_path(compile_id: compile_id, runtime_id: runtime_id, compile_path: compile_path),
                label:        default_compute_label(label: label, runtime_id: runtime_id, task: task),
                data:         data_for(captured_node: node, data: data)
              )
            end
          end

          def self.build_for_stack(stack, **options_for_debugger_node)
            tree, processed = Dev::Trace.Tree(stack.to_a)

            enumerable_tree = Dev::Trace::Tree.Enumerable(tree)

            Dev::Trace::Debugger::Node.build(
              tree,
              enumerable_tree,
              **options_for_debugger_node,
            )
          end
        end
      end # Debugger
    end # Trace
  end
end
