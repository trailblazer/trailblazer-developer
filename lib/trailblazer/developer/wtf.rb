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

      module Invoke
        module_function

        def produce_wtf_node(lib_ctx, flow_options, circuit_options, **)
          node = circuit_options.fetch(:node) # the original node, eg {Create.task_wrap}.
          # whatever wtf looks like internally, we need to build the wtf circuit node and wrap the original node.
          # ideally, this uses the same logic for canonical and for pure.
          id = circuit_options.fetch(:id)
# FIXME: wtf should be wrapping the canonical node, not just the "circuit".

          rescue_node = Wtf::Node.new(**node.to_h) # FIXME: provide generic Node "coerce-cloning" and use it in NodeWrap, too.

          # DISCUSS: we could probably improve performance here.
          wtf_circuit = Circuit::Builder.Pipeline(
            [id, node: rescue_node], # execute the actual activity in begin..rescue.
            [:build_trace, Trace::Present.method(:build_trace_from_stack)],
            [:render, Trace::Present.method(:render_output)],
            [:print, Node.method(:print)],
            [:reraise, Node.method(:reraise)], # DISCUSS: use routing instead of if here.
          )

          node = Circuit::Node[wtf_circuit, Circuit::Processor]

          return lib_ctx, flow_options, circuit_options.merge(node: node, id: "wtf.#{id}")
        end

        def add_flow_options(lib_ctx, flow_options, circuit_options, **)
          wtf_flow_options = {
            segmenter: Trace::Node::Incomplete.method(:segmenter),
            renderer: Renderer, # FIXME: rename to {:trace_node_renderer}?
            render_method: Trace::Present.method(:render),
          }

          return lib_ctx, wtf_flow_options.merge(flow_options), circuit_options # FIXME: test we don't override :renderer.
        end

        # at Invoke time, add the trim_trace step to the Wtf::Node circuit.
        # DISCUSS: maybe the rendering pipe could be a pre-compiled circuit, so we can simply maintain two.
        def add_trim_trace(lib_ctx, flow_options, circuit_options, **)
          node = circuit_options.fetch(:node)

          wtf_circuit_with_trimming = Circuit::Adds.(
            node.task,
            [
              :trim_trace, Circuit::Node[Node.method(:trim_trace), Circuit::Task::Adapter::LibInterface],
              :after, :build_trace
            ]
          )

          node = Circuit::Node[wtf_circuit_with_trimming, Circuit::Processor]

          return lib_ctx, flow_options, circuit_options.merge(node: node)
        end

        Compiler = Circuit::Adds.(
          Activity::Invoke::Args::Compiler,
          [:"trace.flow_options", Circuit::Node[Developer::Trace::Invoke.method(:add_options_for_trace), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"wtf.flow_options", Circuit::Node[Developer::Wtf::Invoke.method(:add_flow_options), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"trace.extensions.wrap_node", Circuit::Node[Developer::Trace::Invoke.method(:add_extension_for_wrap_node_tracing), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"wtf.node", Circuit::Node[Developer::Wtf::Invoke.method(:produce_wtf_node), Circuit::Task::Adapter::LibInterface], :after],
          [:"wtf.node.add_trim_trace", Circuit::Node[Developer::Wtf::Invoke.method(:add_trim_trace), Circuit::Task::Adapter::LibInterface], :after, :"wtf.node"],
        )
      end
    end # Wtf
  end
end
