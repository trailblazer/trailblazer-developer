module Trailblazer::Developer
  module_function

  def wtf(activity, *args)
    Wtf.invoke(activity, *args)
  end

  class << self
    alias wtf? wtf
  end

  module Wtf
    module_function

    DEFAULT_COLOR_MAP = { pass: :green, fail: :brown }

    SIGNALS_MAP = {
      'Trailblazer::Activity::Right': :pass,
      'Trailblazer::Activity::FastTrack::PassFast': :pass,

      'Trailblazer::Activity::Left': :fail,
      'Trailblazer::Activity::FastTrack::FailFast': :fail,
    }

    # Run {activity} with tracing enabled and inject a mutable {Stack} instance.
    # This allows to display the trace even when an exception happened
    def invoke(activity, (ctx, flow_options), *circuit_options)
      activity, (ctx, flow_options), circuit_options = Wtf.arguments_for_trace(
        activity, [ctx, flow_options], *circuit_options
      )

      _returned_stack, signal, (ctx, flow_options) = Trace.invoke(
        activity, [ctx, flow_options], *circuit_options
      )

      return signal, [ctx, flow_options], circuit_options
    ensure
      puts Trace::Present.(
        flow_options[:stack],
        renderer: method(:renderer),
        color_map: DEFAULT_COLOR_MAP.merge( flow_options[:color_map] || {} ),
      )
    end

    def arguments_for_trace(activity, (ctx, original_flow_options), **circuit_options)
      default_flow_options = {
        # this instance gets mutated with every step. unfortunately, there is
        # no other way in Ruby to keep the trace even when an exception was thrown.
        stack: Trace::Stack.new,

        input_data_collector: method(:trace_input_data_collector),
        output_data_collector: method(:trace_output_data_collector),
      }

      # Merge default options with flow_options as an order of precedence
      flow_options = { **default_flow_options, **Hash( original_flow_options ) }

      # Normalize `focus_on` param to
      #   1. Wrap step and variable names into an array if not already
      flow_options[:focus_on] = {
        steps: Array( flow_options.dig(:focus_on, :steps) ),
        variables: Array( flow_options.dig(:focus_on, :variables) ),
      }

      return activity, [ ctx, flow_options ], circuit_options
    end

    # Overring default input and output data collectors to collect/capture
    #   1. inspect of focusable variables for given focusable step
    def trace_input_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data = Trace.default_input_data_collector(wrap_config, [ctx, flow_options], circuit_options)

      if flow_options[:focus_on][:steps].include?(data[:task_name])
        data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      end

      data
    end

    def trace_output_data_collector(wrap_config, (ctx, flow_options), circuit_options)
      data = Trace.default_output_data_collector(wrap_config, [ctx, flow_options], circuit_options)

      input = flow_options[:stack].top
      if flow_options[:focus_on][:steps].include?(input.data[:task_name])
        data[:focused_variables] = Trace::Focusable.capture_variables_from(ctx, **flow_options)
      end

      data
    end

    def renderer(task_node:, position:, tree:)
      if task_node.output.nil? && tree[position.next].nil? # i.e. when exception raised
        return [ task_node.level, %{#{fmt(fmt(task_node.value, :red), :bold)}} ]
      end

      if task_node.output.nil? # i.e. on entry/exit point of activity
        return [ task_node.level, %{#{task_node.value}} ]
      end

      [ task_node.level, %{#{fmt(task_node.value, task_node.color_map[ signal_of(task_node) ])}} ]
    end

    def fmt(line, style)
      return line unless style
      String.send(style, line)
    end

    def signal_of(task_node)
      entity_signal = task_node.output.data[:signal]
      entity_klass = entity_signal.is_a?(Class) ? entity_signal : entity_signal.class

      SIGNALS_MAP[entity_klass.name.to_sym]
    end

    # Stolen from https://stackoverflow.com/questions/1489183/colorized-ruby-output
    #
    # TODO: this is just prototyping
    module String
      module_function
      def black(str);          "\e[30m#{str}\e[0m" end
      def red(str);            "\e[31m#{str}\e[0m" end
      def green(str);          "\e[32m#{str}\e[0m" end
      def brown(str);          "\e[33m#{str}\e[0m" end
      def blue(str);           "\e[34m#{str}\e[0m" end
      def magenta(str);        "\e[35m#{str}\e[0m" end
      def cyan(str);           "\e[36m#{str}\e[0m" end
      def gray(str);           "\e[37m#{str}\e[0m" end

      def bg_black(str);       "\e[40m#{str}\e[0m" end
      def bg_red(str);         "\e[41m#{str}\e[0m" end
      def bg_green(str);       "\e[42m#{str}\e[0m" end
      def bg_brown(str);       "\e[43m#{str}\e[0m" end
      def bg_blue(str);        "\e[44m#{str}\e[0m" end
      def bg_magenta(str);     "\e[45m#{str}\e[0m" end
      def bg_cyan(str);        "\e[46m#{str}\e[0m" end
      def bg_gray(str);        "\e[47m#{str}\e[0m" end

      def bold(str);           "\e[1m#{str}\e[22m" end
      def italic(str);         "\e[3m#{str}\e[23m" end
      def underline(str);      "\e[4m#{str}\e[24m" end
      def blink(str);          "\e[5m#{str}\e[25m" end
      def reverse_color(str);  "\e[7m#{str}\e[27m" end
    end
  end
end
