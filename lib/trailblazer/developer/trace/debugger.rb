module Trailblazer
  module Developer
    module Trace
      module Debugger
        class Node
          # The idea is to only work with {Activity} instances on this level, as that's the runtime concept.
          def initialize(captured_node:, compile_id:, runtime_id:, activity:, task:, compile_path:, runtime_path:, label:, data:, **)
            @captured_node  = captured_node # DISCUSS: private?
            @activity       = activity # this is the {Activity} *instance* running this {task}.
            @task           = task
            @compile_id     = compile_id
            @runtime_id     = runtime_id
            @compile_path   = compile_path
            @runtime_path   = runtime_path
            @level          = @captured_node.level
            @label          = label
            @data           = data
            @captured_input = captured_node.captured_input
            @captured_output = captured_node.captured_output

            # class, "type",
            # which track, return signal, etc
          end

          attr_reader :task, :compile_path, :compile_id, :runtime_path, :runtime_id, :level, :captured_node, :label, :data, :captured_input, :captured_output


          # we always key options for specific nodes by Stack::Captured::Input, so we don't confuse activities if they were called multiple times.
          def self.build(tree, enumerable_tree, node_options: {}, normalizer: Debugger::Normalizer::PIPELINES.last, **options_for_nodes)
            parent_map = Trace::Tree::ParentMap.build(tree).to_h # DISCUSS: can we use {enumerable_tree} for {ParentMap}?


            container_activity = enumerable_tree[0].captured_input.activity # TODO: any other way to grab the container_activity? Maybe via {activity.container_activity}?

  # TODO: cache activity graph
            top_activity = enumerable_tree[0].captured_input.task

            task_maps_per_activity = {
              container_activity => {top_activity => {id: nil}} # exposes {Introspect::TaskMap}-compatible interface.
            }

            # DISCUSS: this might change if we introduce a new Node type for Trace.
            debugger_nodes = enumerable_tree[0..-1].collect do |node|
              activity      = node.captured_input.activity
              task          = node.captured_input.task
              # it's possible to pass per-node options, like {label: "Yo!"} via {:node_options[<captured_input>]}
              options       = node_options[node.captured_input] || {}



              task_map_for_activity = task_maps_per_activity[activity] || Activity::Introspect.TaskMap(activity)

              options_for_debugger_node, _ = normalizer.(
                {
                  captured_node:          node,
                  task:                   task,
                  activity:               activity,
                  parent_map:             parent_map,
                  task_map_for_activity:  task_map_for_activity,
                  **options
                },
                []
              )

              # these attributes are not changing with the presentation
              Debugger::Node.new(
                captured_node: node,
                activity: activity,
                task: task,

                **options_for_debugger_node,
              )
            end
          end

          def self.build_for_stack(stack, **options_for_debugger_nodes)
            tree, processed = Trace.Tree(stack.to_a)

            enumerable_tree = Trace::Tree.Enumerable(tree)

            Debugger::Node.build(
              tree,
              enumerable_tree,
              **options_for_debugger_nodes,
            )
          end
        end
      end # Debugger
    end # Trace
  end
end
