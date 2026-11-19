module Trailblazer
  module Developer
    def self.wtf?(circuit, target_ctx, compiler: Wtf::Invoke::Compiler, only_application: false, **options_for_invoke)
      if only_application
        compiler = Wtf::Application::Invoke::Compiler
      end

      lib_ctx = {target_ctx: target_ctx} # FIXME: use {produce_lib_ctx} step.

      Activity::Invoke.(circuit, lib_ctx, **options_for_invoke, extensions: [], compiler: compiler) # FIXME: default :extensions.
    end

    module Wtf
      class Node < Trailblazer::Circuit::Node
        def call(lib_ctx, flow_options, signal, **circuit_options)
          begin
            lib_ctx, flow_options, signal = super
          rescue
            flow_options = flow_options.merge(exception: $!)
          end

          return lib_ctx, flow_options, signal
        end

        def self.trim_trace(lib_ctx, flow_options, signal, **circuit_options)
          trace = flow_options.fetch(:trace)

          trace = trace [1..-2] # Cut off {<wtf.Create} and {<wtf.trim_trace}. # DISCUSS: not sure this is the final implementation.
          # unindent by one level, since {wtf.Create} was level=0 and is now gone.
          trace = trace.collect { |trace_node| trace_node.level = trace_node.level - 1; trace_node } # FIXME: use Trace::Node.clone

          return lib_ctx, flow_options.merge(trace: trace), signal
        end

        def self.print(lib_ctx, flow_options, signal, **)
          puts flow_options.fetch(:output)

          return lib_ctx, flow_options, signal
        end

        def self.reraise(lib_ctx, flow_options, signal, **)
          exception = flow_options[:exception]

          raise exception if exception

          return lib_ctx, flow_options, signal
        end
      end

      # DISCUSS: Behavior?
      dont_trace_options = {options: {already_wrapped: true}}

      Present = Circuit::Builder.Pipeline(
        [:build_trace, Trace::Present.method(:build_trace_from_stack), dont_trace_options],
        [:render, Trace::Present.method(:render_output)],
        [:print, Node.method(:print)],
        [:reraise, Node.method(:reraise)], # DISCUSS: use routing instead of if here.
      )

      # module TaskWrap
        module Extension
          module_function

          # basically, only apply this once, to the very top canonical node.
          CONDITION = ->(*, node, id) { node.options[:canonical] && node.options[:task_wrap] && ! node.is_a?(Wtf::Node) }

          def produce_wtf_node(*args, node, id)
            # puts "@@@@@/ #{id.inspect}";

            # whatever wtf looks like internally, we need to build the wtf circuit node and wrap the original node.
            # ideally, this uses the same logic for canonical and for pure.

            rescue_node = Wtf::Node.new(**node.to_h) # FIXME: provide generic Node "coerce-cloning" and use it in NodeWrap, too.

            wtf_circuit = Circuit::Builder.Pipeline(
              [id, node: rescue_node], # execute the actual activity in begin..rescue.
              [:"wtf.present", Present, Circuit::Processor, options: {already_wrapped: true}]
            )

            # FIXME: {already_wrapped: true} means "don't trace me", currently, but only in WrapNode mode.
            node = Circuit::Node[wtf_circuit, Circuit::Processor, options: {already_wrapped: true}] # this is the new canonical node named :"wtf.#{id}"

            return *args, node, :"wtf.#{id}"
          end


          ProduceWtfNode = Circuit::WrapRuntime::Extension.new(
            # only execute this for the very top node, the canonical tW.
            Extension::CONDITION,
            Extension.method(:produce_wtf_node)
          )
        end

      module Invoke
        module_function

        def add_flow_options(lib_ctx, _, (ctx, runner), **)
          wtf_flow_options = {
            segmenter: Trace::Node::Incomplete.method(:segmenter),
            renderer: Renderer, # FIXME: rename to {:trace_node_renderer}?
            render_method: Trace::Present.method(:render),
          }

          return lib_ctx, _, [ctx, runner.reverse_merge(**wtf_flow_options)]  # FIXME: test we don't override :renderer.
        end

        def add_circuit_options(lib_ctx, _, args, extensions:, **)
          extensions = [Extension::ProduceWtfNode] + extensions

          return lib_ctx.merge(extensions: extensions), _, args
        end

        Compiler = Circuit::Adds.(
          Activity::Invoke::Args::Compiler,
          [:"trace.flow_options", Circuit::Node[Developer::Trace::Invoke.method(:add_options_for_trace), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"wtf.flow_options", Circuit::Node[Developer::Wtf::Invoke.method(:add_flow_options), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"wtf.circuit_options", Circuit::Node[Developer::Wtf::Invoke.method(:add_circuit_options), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"trace.extensions.wrap_node", Circuit::Node[Developer::Trace::Invoke.method(:add_extension_for_wrap_node_tracing), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
        )
      end
    end # Wtf
  end
end
