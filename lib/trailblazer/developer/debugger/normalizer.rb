module Trailblazer
  module Developer
    module Debugger
      # @private
      # Public entry point to add Debugger::Node normalizer steps.
      def self.add_normalizer_step!(step, id:, normalizer: Normalizer::PIPELINES.last, **options)
        task = Normalizer.Task(step) # FIXME.

        # We have a TaskWrap::Pipeline (a very simple style of "activity" used for normalizers) and
        # add another step using the "friendly interface" from {Activity::Adds}.
        options = {append: nil} unless options.any?

        pipeline_extension = Activity::TaskWrap::Extension.build([task, id: id, **options])

        Normalizer::PIPELINES << pipeline_extension.(normalizer)
      end

      # Run at runtime when preparing a Trace::Nodes for presentation.
      module Normalizer
        def self.Task(user_step)
          Activity::DSL::Linear::Normalizer.Task(user_step)
        end

        # Default steps for the Debugger::Node options pipeline, following the step-interface.
        module Default
          def self.compile_id(ctx, flow_options, _, activity:, task:, **)
            ctx = ctx.merge(:compile_id => Activity::Introspect.Nodes(activity, task: task)[:id])
            return ctx, flow_options
          end

          def self.runtime_id(ctx, flow_options, _, compile_id:, **)
            ctx = ctx.merge(:runtime_id => compile_id)
            return ctx, flow_options
          end

          def self.label(ctx, flow_options, _, label: nil, runtime_id:, **)
            ctx = ctx.merge(:label => label || runtime_id)
            return ctx, flow_options
          end

          def self.data(ctx, flow_options, _, data: {}, **)
            ctx = ctx.merge(:data => data)
            return ctx, flow_options
          end

          def self.incomplete?(ctx, flow_options, _, trace_node:, **)
            ctx = ctx.merge(:incomplete? => trace_node.is_a?(Developer::Trace::Node::Incomplete))
            return ctx, flow_options
          end
        end

        default_steps = {
          compile_id:       Default.method(:compile_id),
          runtime_id:       Default.method(:runtime_id),
          label:            Default.method(:label),
          data:             Default.method(:data),
          incomplete?:      Default.method(:incomplete?),
        }

        PIPELINES = [Activity.Pipeline(default_steps)] # we do mutate this constant at compile-time. Maybe # DISCUSS and find a better way.
      end
    end
  end
end
