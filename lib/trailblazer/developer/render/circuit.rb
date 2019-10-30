module Trailblazer
  module Developer
    module_function

    def render(activity)
      Render::Circuit.(activity)
    end

    module Render
      module Circuit
        module_function

        # Render an {Activity}'s circuit as a simple hash.
        def call(activity, **options)
          graph = Activity::Introspect::Graph(activity)

          circuit_hash(graph, **options)
        end

        def circuit_hash(graph, **options)
          content = graph.collect do |node|
            conns = node.outgoings.collect do |outgoing|
              " {#{outgoing.output.signal}} => #{inspect_with_matcher(outgoing.task, **options)}"
            end

            [ inspect_with_matcher(node.task, **options), conns.join("\n") ]
          end

          content = content.join("\n")

          return "\n#{content}".gsub(/0x\w+/, "0x")#.gsub(/0.\d+/, "0.")
        end

        # If Ruby had pattern matching, this function wasn't necessary.
        def inspect_with_matcher(task, inspect_task: method(:inspect_task), inspect_end: method(:inspect_end))
          return inspect_task.(task) unless task.kind_of?(Trailblazer::Activity::End)
          inspect_end.(task)
        end

        def inspect_task(task)
          task.inspect
        end

        def inspect_end(task)
          class_name = self.class.strip(task.class)
          options    = task.to_h

          "#<#{class_name}/#{options[:semantic].inspect}>"
        end

        def self.strip(string)
          string.to_s.sub("Trailblazer::Activity::", "")
        end
      end
    end
  end
end
