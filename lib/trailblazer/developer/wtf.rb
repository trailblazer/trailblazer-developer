module Trailblazer
  module Developer
    module Wtf
      class Node < Trailblazer::Circuit::Node
        def call(lib_ctx, flow_options, signal, **circuit_options)
          exception = false

          begin
            super
          rescue
            exception = $!
          end

          # DISCUSS: rendering could happen in a separate, asyncable step.
          output = Trailblazer::Developer::Trace::Present.(
            flow_options[:stack],
            segmenter: Trace::Node::Incomplete.method(:segmenter),
            renderer: Renderer,
          )

          puts output
          raise exception if exception

          return lib_ctx, flow_options, signal
        end
      end

      module Invoke
        def self.produce_wtf_node(lib_ctx, flow_options, circuit_options, **)
          node = circuit_options.fetch(:node) # the original node, eg {Create.task_wrap}.
          # whatever wtf looks like internally, we need to build the wtf circuit node and wrap the original node.
          # ideally, this uses the same logic for canonical and for pure.

          # DISCUSS: the whole Wtf? logic could be a pipe, where one step can render and be async?
          wtf_circuit = Circuit::Builder.Pipeline(
            [:wtf_top_canonical, node: node]
          )
          wtf_node = Wtf::Node[wtf_circuit, Circuit::Processor]

          return lib_ctx, flow_options, circuit_options.merge(node: wtf_node)
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

        def call(trace_node:, trace:, **)
          label = %(#{trace_node.id})

          label =
            if trace_node.is_a?(Trace::Node::Incomplete)
              color_key = :gray

              if trace_node == trace.last # we assume this is the root of all evil resp. of the exception.
                color_key = :bold_red
              end

              colorize(label, COLORS[color_key])
            else
              returned_signal = trace_node.snapshot_after.data.fetch(:signal)

              color_key = SIGNAL_TO_COLOR_KEY[returned_signal]

              colorize(label, COLORS[color_key])
            end

          [trace_node.level, label]
        end

        def colorize(string, color)
          "#{color}#{string}\e[0m"
        end
      end
    end
  end
end
