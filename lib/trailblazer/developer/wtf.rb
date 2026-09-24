module Trailblazer
  module Developer
    def self.wtf?(circuit, target_ctx, **options_for_invoke)
      lib_ctx = {target_ctx: target_ctx} # FIXME: use {produce_lib_ctx} step.

      Activity::Invoke.(circuit, lib_ctx, **options_for_invoke, extensions: [], conditions: []) # FIXME: default :extensions.
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
          # DISCUSS: rendering could happen in a separate, asyncable step.
          output = Trailblazer::Developer::Trace::Present.(
            flow_options[:stack],
            segmenter: Trace::Node::Incomplete.method(:segmenter),
            renderer: Renderer,
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

          rescue_node = Wtf::Node.new(**node.to_h) # FIXME: provide generic Node "coerce-cloning" and use it in NodeWrap, too.

          options_for_node = {options: {trace: false}}

          wtf_circuit = Circuit::Builder.Pipeline(
            [id, node: rescue_node, **options_for_node], # execute the actual activity in begin..rescue.
            [:render, Node.method(:render), Circuit::Task::Adapter::LibInterface, **options_for_node],
            [:print, Node.method(:print), Circuit::Task::Adapter::LibInterface, **options_for_node],
            [:reraise, Node.method(:reraise), Circuit::Task::Adapter::LibInterface, **options_for_node], # DISCUSS: use routing instead of if here.
          )

          node = Circuit::Node[wtf_circuit, Circuit::Processor, **options_for_node]

          return lib_ctx, flow_options, circuit_options.merge(node: node)
        end

        CONDITION_FOR_BUSINESS_STEP = ->(node:, **) { node.to_h[:options][:business_step] } # The :business_step option is set in the dsl gem.
        CONDITION_FOR_TRACE_FLAG = ->(node:, **) { ! (node.to_h[:options][:trace] === false) } # we set the :trace flag in the wtf pipeline.

        def produce_condition(lib_ctx, flow_options, circuit_options, **)
          only_business_nodes = circuit_options[:only_business_nodes] || false
          conditions = circuit_options.fetch(:conditions)

          if only_business_nodes
            conditions += [CONDITION_FOR_BUSINESS_STEP]
          end

          conditions += [CONDITION_FOR_TRACE_FLAG]

          return lib_ctx, flow_options, circuit_options.merge(conditions: conditions)
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
