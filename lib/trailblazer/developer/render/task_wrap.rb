module Trailblazer
  module Developer
    module Render
      module TaskWrap
        # @param activity Trailblazer::Activity
        def self.render_for(activity, node)
          task_wrap = task_wrap_for_activity(activity) # TODO: MERGE WITH BELOW
          task      = node.task
          step_wrap = task_wrap[task] # the taskWrap for the actual step, e.g. {input,call_task,output}.

          level = 2
          nodes = render_pipeline(step_wrap, level)

          nodes = [[0, activity], [1, node.id], *nodes]

          Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
        end

        # @param activity Activity
        def self.task_wrap_for_activity(activity, **)
          activity[:wrap_static]
        end

        def self.render_pipeline(pipeline, level)
          renderers = Hash.new(method(:render_task_wrap_step))
          renderers.merge!(
            Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input => method(:render_input),
            Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output => method(:render_input),
          )
# TODO: use collect
          nodes=[]

          pipeline.to_a.collect do |row|
            renderer = renderers[row[1].class]

            nodes = nodes + renderer.(row, level) # call the rendering component.
          end

          nodes
        end

        def self.render_task_wrap_step(row, level)
          text = row.id.to_s.ljust(33, ".") + row[1].class.to_s

          [[level, text]]
        end

        def self.render_input(row, level)
          input_pipe = row[1].instance_variable_get(:@pipe) # this is again a {TaskWrap::Pipeline}.

          filters = input_pipe.to_a.collect do |id, filter|

            id, class_name, info =
              if filter.is_a?(Activity::DSL::Linear::VariableMapping::AddVariables)
                if id =~ /inject\./ # TODO: maybe Inject() should be encapsulated in {AddVariables::Inject}?

                  [id, filter.class.to_s.match(/VariableMapping::.+/), ""]
                else
                  _info       = filter.instance_variable_get(:@user_filter).inspect # we could even grab the source code for callables here!
                  rendered_id = "#{id.match(/.+0\.\w\w\w/)}[...]"

                  [rendered_id, filter.class.to_s.match(/VariableMapping::.+/), _info]
                end

              else # generic VariableMapping::DSL step such as {VariableMapping.scope}
                _name = filter.inspect.match(/VariableMapping\.\w+/)

                [id.to_s, _name, ""]
              end

            text =  "#{id.ljust(45, ".")} #{info.ljust(45, ".")} #{class_name}"

            [level+1, text]
          end

          # pp filters
          render_task_wrap_step(row, level) + filters
          # render_task_wrap_step(row, level)
        end
      end
    end
  end
end
