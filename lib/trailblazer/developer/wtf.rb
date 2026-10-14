module Trailblazer
  module Developer
    def self.wtf?(circuit, target_ctx, compiler: Wtf::Invoke::Compiler, only_application: false, **options_for_invoke)
      if only_application
        compiler = Wtf::Rly::Invoke::Compiler

        options_for_invoke = options_for_invoke.merge(flow_options: {trim_stack: false})
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

        def self.render(lib_ctx, flow_options, signal, **)
          renderer = flow_options[:renderer] || Renderer # TODO: test me in developer.

          stack = flow_options[:stack]

          trim_stack = flow_options.key?(:trim_stack) ? flow_options[:trim_stack] : true # DISCUSS: not super happy with this flag, but moving it to another step breaks the trimming.
          if trim_stack
            stack = flow_options[:stack].to_a.to_a
            # pp stack.to_a.values[0]
            # pp stack.to_a.values[-1]
            stack = stack[1..-2] # Cut off {<wtf.Create} and {<wtf.render}. # DISCUSS: not sure this is the final implementation.
          end

          # DISCUSS: rendering could happen in a separate, asyncable step.
          output = Trailblazer::Developer::Trace::Present.(
            stack,
            segmenter: Trace::Node::Incomplete.method(:segmenter),
            renderer: renderer,
            exception: flow_options[:exception],
          )

          return lib_ctx, flow_options.merge(output: output), signal
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
            [:render, Node.method(:render)],
            [:print, Node.method(:print)],
            [:reraise, Node.method(:reraise)], # DISCUSS: use routing instead of if here.
          )

          node = Circuit::Node[wtf_circuit, Circuit::Processor]

          return lib_ctx, flow_options, circuit_options.merge(node: node, id: "wtf.#{id}")
        end

        Compiler = Circuit::Adds.(
          Activity::Invoke::Args::Compiler,
          [:"trace.flow_options", Circuit::Node[Developer::Trace::Invoke.method(:add_options_for_trace), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"trace.extensions.wrap_node", Circuit::Node[Developer::Trace::Invoke.method(:add_extension_for_wrap_node_tracing), Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
          [:"wtf.node", Circuit::Node[Developer::Wtf::Invoke.method(:produce_wtf_node), Circuit::Task::Adapter::LibInterface], :after],
        )

        # Trailblazer::Developer.puts(Compiler)
      end

      module Rly # TODO: move.
        module Invoke
          Compiler = Circuit::Adds.(
            Wtf::Invoke::Compiler,
            [
              :"trace.extensions.extend_task_wrap",
              Circuit::Node[Trace::Invoke.method(:add_extension_for_application_tracing), Circuit::Task::Adapter::LibInterface],
              :replace, :"trace.extensions.wrap_node"
            ],
          )
        end
      end

      module Renderer
        module_function

        COLORS = {
          gray: "\e[37m", # we don't know the signal, it's not recorded. hence "gray", like a map.
          green: "\e[32m",
          brown: "\e[33m",
          red: "\e[31m",
          bold_red: "\e[31m\e[1m",
          black: "\e[30m",  # we cannot interpret the signal.
        }

        SIGNAL_TO_COLOR_KEY = Hash.new(:black)
        SIGNAL_TO_COLOR_KEY.merge!( # TODO: allow to lookup nested OP's semantic etc!
          Activity::Right => :green,
          Activity::Left => :brown,
        )

        def call(trace_node:, trace:, exception:, **)
          label = %(#{trace_node.id})

          color_key =
            if trace_node == trace.last && exception  # we assume this is the root of all evil resp. of the exception.
              :bold_red
            elsif trace_node.is_a?(Trace::Node::Incomplete)
              :gray
            else
              returned_signal = trace_node.snapshot_after.data.fetch(:signal)

              SIGNAL_TO_COLOR_KEY[returned_signal]
            end

          label = colorize(label, COLORS[color_key])

          [trace_node.level, label]
        end

        def colorize(string, color)
          "#{color}#{string}\e[0m"
        end
      end
    end
  end
end
