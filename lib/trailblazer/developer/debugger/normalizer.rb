module Trailblazer
  module Developer
    module Debugger
      # @private
      # Public entry point to add Debugger::Node normalizer steps.
      def self.add_normalizer_step!(step, id:, normalizer: Normalizer::PIPELINES.last, **options)
        task = Normalizer.Task(step)

        # We have a TaskWrap::Pipeline (a very simple style of "activity" used for normalizers) and
        # add another step using the "friendly interface" from {Activity::Adds}.
        options = {append: nil} unless options.any?

        pipeline_extension = Activity::TaskWrap::Extension.build([task, id: id, **options])

        Normalizer::PIPELINES << pipeline_extension.(normalizer)
      end

      module Normalizer
        def self.Task(user_step) # TODO: we could keep this in the {activity} gem.
          Activity::TaskWrap::Pipeline::TaskAdapter.for_step(user_step, option: false) # we don't need Option as we don't have ciruit_options here, and no {:exec_context}
        end

        # Default steps for the Debugger::Node options pipeline, following the step-interface.
        module Default
          def self.compile_id(ctx, activity:, task:, **)
            ctx[:compile_id] = Activity::Introspect.Nodes(activity, task: task)[:id]
          end

          def self.compile_path(ctx, parent_map:, captured_node:, **)
            ctx[:compile_path] = Developer::Trace::Tree::ParentMap.path_for(parent_map, captured_node)
          end

          def self.runtime_id(ctx, compile_id:, **)
            ctx[:runtime_id] = compile_id
          end

          def self.runtime_path(ctx, runtime_id:, compile_path:, **)
            return ctx[:runtime_path] = compile_path if compile_path.empty? # FIXME: this currently only applies to root.

            ctx[:runtime_path] = compile_path[0..-2] + [runtime_id]
          end

          def self.label(ctx, label: nil, runtime_id:, **)
            ctx[:label] = label || runtime_id
          end

          def self.data(ctx, data: {}, **)
            ctx[:data] = data
          end
        end

        default_steps = {
          compile_id:       Normalizer.Task(Default.method(:compile_id)),
          compile_path:     Normalizer.Task(Default.method(:compile_path)),
          runtime_id:       Normalizer.Task(Default.method(:runtime_id)),
          runtime_path:     Normalizer.Task(Default.method(:runtime_path)),
          label:            Normalizer.Task(Default.method(:label)),
          data:             Normalizer.Task(Default.method(:data)),
        }.
        collect { |id, task| Activity::TaskWrap::Pipeline.Row(id, task) }

        PIPELINES = [Activity::TaskWrap::Pipeline.new(default_steps)] # we do mutate this constant at compile-time. Maybe # DISCUSS and find a better way.
      end
    end
  end
end
