module Trailblazer
  module Developer
    module Trace
      module Debugger
        class Node < Struct.new(:captured_node, :task, :activity, :compile_id, :compile_path, :runtime_id, :runtime_path, :label, :data, :snapshot_before, :snapshot_after, :level, keyword_init: true)
          # The idea is to only work with {Activity} instances on this level, as that's the runtime concept.

            # TODO: class, "type",
            # which track, return signal, etc


          # we always key options for specific nodes by Stack::Captured::Input, so we don't confuse activities if they were called multiple times.
          def self.build(tree, enumerable_tree, node_options: {}, normalizer: Debugger::Normalizer::PIPELINES.last, **options_for_nodes)
            parent_map = Trace::Tree::ParentMap.build(tree).to_h # DISCUSS: can we use {enumerable_tree} for {ParentMap}?


            container_activity = enumerable_tree[0].snapshot_before.activity # TODO: any other way to grab the container_activity? Maybe via {activity.container_activity}?

            top_activity = enumerable_tree[0].snapshot_before.task

            # DISCUSS: this might change if we introduce a new Node type for Trace.
            debugger_nodes = enumerable_tree.collect do |node|
              activity = node.snapshot_before.activity
              task     = node.snapshot_before.task
              # it's possible to pass per-node options, like {label: "Yo!"} via {:node_options[<snapshot_before>]}
              options  = node_options[node.snapshot_before] || {}


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
                snapshot_before: node.snapshot_before,
                snapshot_after:  node.snapshot_after,

                **options_for_debugger_node,
              ).freeze
            end
          end

          # Called in {Trace::Present}.
          # Design note: goal here is to have as little computation as possible, e.g. not sure
          #              if we should calculate pathes here all times.
          def self.build_for_stack(stack, **options_for_debugger_nodes)
            tree, processed = Trace.Tree(stack.to_a)

            enumerable_tree = Trace::Tree.Enumerable(tree)

            nodes = Debugger::Node.build(
              tree,
              enumerable_tree,
              **options_for_debugger_nodes,
            )

            Traced.new(nodes: nodes, variable_versions: stack.variable_versions) # after this, the concept of "Stack" doesn't exist anymore.
          end

          # Used to transport data other than {nodes} to the presentation layer.
          # We have no concept of {Stack} here anymore. Nodes and arbitrary objects such as "versions".
          # Debugger::Traced interface abstracts away the fact we have two snapshots. Here,
          # we only have a node per task.
          #
          class Traced # DISCUSS: this could be called "Trace" because it much better describes what this is. "Verlauf"
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
        end
      end # Debugger
    end # Trace
  end
end
