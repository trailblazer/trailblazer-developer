module Trailblazer
  module Developer
    module Trace
      module Debugger
        class Node < Struct.new(:captured_node, :task, :activity, :compile_id, :compile_path, :runtime_id, :runtime_path, :label, :data, :captured_input, :captured_output, :level, keyword_init: true)
          # The idea is to only work with {Activity} instances on this level, as that's the runtime concept.

            # TODO: class, "type",
            # which track, return signal, etc


          # we always key options for specific nodes by Stack::Captured::Input, so we don't confuse activities if they were called multiple times.
          def self.build(tree, enumerable_tree, node_options: {}, normalizer: Debugger::Normalizer::PIPELINES.last, **options_for_nodes)
            parent_map = Trace::Tree::ParentMap.build(tree).to_h # DISCUSS: can we use {enumerable_tree} for {ParentMap}?


            container_activity = enumerable_tree[0].captured_input.activity # TODO: any other way to grab the container_activity? Maybe via {activity.container_activity}?

            top_activity = enumerable_tree[0].captured_input.task

            # DISCUSS: this might change if we introduce a new Node type for Trace.
            debugger_nodes = enumerable_tree.collect do |node|
              activity = node.captured_input.activity
              task     = node.captured_input.task
              # it's possible to pass per-node options, like {label: "Yo!"} via {:node_options[<captured_input>]}
              options  = node_options[node.captured_input] || {}


              options_for_debugger_node, _ = normalizer.(
                {
                  captured_node:          node,
                  task:                   task,
                  activity:               activity,
                  parent_map:             parent_map,
                  **options
                },
                []
              )

              options_for_debugger_node = options_for_debugger_node.slice(*(options_for_debugger_node.keys - [:parent_map]))

              # these attributes are not changing with the presentation
              Debugger::Node.new(
                captured_node:  node,
                activity:       activity,
                task:           task,

                level: node.level,
                captured_input: node.captured_input,
                captured_output: node.captured_output,

                **options_for_debugger_node,
              ).freeze
            end
          end

          # Called in {Trace::Present}.
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
