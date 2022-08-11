module Trailblazer
  module Developer
    module Render
      module TaskWrap
        def self.call(activity, id:)
          task_wrap = activity.to_h[:config][:wrap_static]



          task      = Activity::Introspect.Graph(activity).find(id).task
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

puts "yo"
            pp renderer.(row, level) # call the rendering component.
            nodes = nodes + renderer.(row, level) # call the rendering component.
          end
puts
          pp nodes

          nodes = [[0, activity], [1, id], *nodes]

          puts Hirb::Console.format_output(nodes, class: :tree, type: :directory, multi_line_nodes: true)
        end

        def self.render_task_wrap_step(row, level)
          text = row.id.to_s.ljust(33, ".") + row[1].class.to_s

          [[level, text]]
        end

        def self.render_input(row, level)
          input_pipe = row[1].instance_variable_get(:@pipe) # this is again a {TaskWrap::Pipeline}.

          filters = input_pipe.to_a.collect do |id, filter|

            text =  "#{id.to_s.ljust(33, ".")} #{filter.is_a?(Activity::DSL::Linear::VariableMapping::AddVariables) ? filter.instance_variable_get(:@user_filter).inspect : filter.inspect.match(/VariableMapping\.\w+/) }" # we could even grab the source code for callables here!

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
