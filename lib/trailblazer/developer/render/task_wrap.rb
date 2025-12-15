module Trailblazer
  module Developer
    module Render
      module TaskWrap
        module_function

        # @param activity Trailblazer::Activity
        def render_for(activity, node)
          task_wrap = task_wrap_for_activity(activity) # TODO: MERGE WITH BELOW
          task      = node.task
          step_wrap = task_wrap[task] # the taskWrap for the actual step, e.g. {input,call_task,output}.

          level = 2
          nodes = render_pipeline(step_wrap, level)

          nodes = [[0, activity], [1, node.id], *nodes]

          Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
        end

        # @param activity Activity
        def task_wrap_for_activity(activity, **)
          activity.to_h[:config][:wrap_static]
        end

        def render_pipeline(pipeline, level)
          renderers = Hash.new(method(:render_task_wrap_step))
          renderers.merge!(
            # Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input => method(:render_input),
            # Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output => method(:render_input),
            Method => method(:render_method),
          )
# TODO: use collect
          nodes=[]

          pipeline.to_a.collect do |id, row|
            renderer = renderers[row.class]

            name, type = renderer.(id, row, level)

            nodes = nodes + format_line(name, type, level)

            if row.is_a?(Activity::Pipeline)
              nodes += render_pipeline(row, level + 1)
            end

          end

          nodes
        end

        def format_line(name, type, level)
          offset = level * 4

          text = name.to_s.ljust(66 - offset, ".") + type

          [[level, text]]
        end

        # Default renderer for tW step.
        def render_task_wrap_step(id, task, level)
          type = task.is_a?(Class) ? task.class.to_s : task.to_s

          return id, type
        end

        def render_method(id, method, level)
          name = method.to_s.sub("#<Method: ", "")
          puts "@@@@@ #{name.inspect}"
          m = name.match(/^(.+?)( |\()/)

          name = m[1]

          name = name.sub("Trailblazer::Activity::DSL::Linear::", "") # DISCUSS: too specific.

          name = "Method: #{name}"

          return id, name
        end
      end
    end
  end
end
