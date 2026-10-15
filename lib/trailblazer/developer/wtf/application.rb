module Trailblazer
  module Developer
    module Wtf
      # The args-compiler for the Operation.wtf? style trace, where we show
      # only application nodes.
      module Application
        module Invoke
          Compiler = Circuit::Adds.(
            Wtf::Invoke::Compiler,
            [
              :"trace.extensions.extend_task_wrap",
              Circuit::Node[Trace::Invoke.method(:add_extension_for_application_tracing), Circuit::Task::Adapter::LibInterface],
              :replace, :"trace.extensions.wrap_node"
            ],
            [
              nil,
              nil,
              :delete, :"wtf.node.add_trim_trace"
            ]
          )
          # Trailblazer::Developer.puts(Compiler)
        end
      end
    end
  end
end
