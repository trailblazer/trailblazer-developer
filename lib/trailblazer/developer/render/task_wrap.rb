module Trailblazer
  module Developer
    module Render
      module TaskWrap
        def self.call(activity, segments)
          node      = Introspect.find_path(activity, segments)
          activity  = node.activity

          task_wrap = activity.to_h[:config][:wrap_static]
          task      = node.task
          step_wrap = task_wrap[task] # the taskWrap for the actual step, e.g. {input,call_task,output}.

          renderers = Hash.new(method(:render_task_wrap_step))
          renderers.merge!(
            Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input => method(:render_input),
            Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output => method(:render_input),
          )

          nodes = []

          level = 2
          step_wrap.to_a.each do |row|
            renderer = renderers[row[1].class]

            nodes = nodes + renderer.(row, level) # call the rendering component.
          end

          nodes = [[0, activity], [1, node.id], *nodes]

          Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
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
