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

      # Run at runtime when preparing a Trace::Nodes for presentation.
      module Normalizer
        def self.Task(user_step) # TODO: we could keep this in the {activity} gem.
          Activity::TaskWrap::Pipeline::TaskAdapter.for_step(user_step, option: false) # we don't need Option as we don't have ciruit_options here, and no {:exec_context}
        end

        # Default steps for the Debugger::Node options pipeline, following the step-interface.
        module Default
          def self.compile_id(ctx, activity:, task:, **)
            ctx[:compile_id] = Activity::Introspect.Nodes(activity, task: task)[:id]
          end

          def self.runtime_id(ctx, compile_id:, **)
            ctx[:runtime_id] = compile_id
          end

          def self.label(ctx, label: nil, runtime_id:, **)
            ctx[:label] = label || runtime_id
          end

          def self.data(ctx, data: {}, **)
            ctx[:data] = data
          end

          def self.incomplete?(ctx, trace_node:, **)
            ctx[:incomplete?] = trace_node.is_a?(Developer::Trace::Node::Incomplete)
          end
        end

        default_steps = {
          compile_id:       Normalizer.Task(Default.method(:compile_id)),
          runtime_id:       Normalizer.Task(Default.method(:runtime_id)),
          label:            Normalizer.Task(Default.method(:label)),
          data:             Normalizer.Task(Default.method(:data)),
          incomplete?:      Normalizer.Task(Default.method(:incomplete?)),
        }.
        collect { |id, task| Activity::TaskWrap::Pipeline.Row(id, task) }

        PIPELINES = [Activity::TaskWrap::Pipeline.new(default_steps)] # we do mutate this constant at compile-time. Maybe # DISCUSS and find a better way.
      end
    end
  end
end
