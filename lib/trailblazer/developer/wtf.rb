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

    COLOR_MAP = { pass: :green, fail: :brown }

    SIGNALS_MAP = {
      'Trailblazer::Activity::Right': :pass,
      'Trailblazer::Activity::FastTrack::PassFast': :pass,

      'Trailblazer::Activity::Left': :fail,
      'Trailblazer::Activity::FastTrack::FailFast': :fail,
    }

    # Run {activity} with tracing enabled and inject a mutable {Stack} instance.
    # This allows to display the trace even when an exception happened
    def invoke(activity, (ctx, flow_options), *args)
      flow_options ||= {} # Ruby sucks.

      # this instance gets mutated with every step. unfortunately, there is
      # no other way in Ruby to keep the trace even when an exception was thrown.
      stack = Trace::Stack.new

      _returned_stack, *returned = Trace.invoke(
        activity,
        [
          ctx,
          flow_options.merge(stack: stack)
        ],
        *args
      )

      returned
    ensure
      puts Trace::Present.(
        stack,
        renderer: method(:renderer),
        color_map: COLOR_MAP.merge( flow_options[:color_map] || {} )
      )
    end

    def renderer(task_node:, position:, tree:)
      name, level, output, color_map = task_node.values_at(:name, :level, :output, :color_map)

      if output.nil? && tree[position.next].nil? # i.e. when exception raised
        return [ level, %{#{fmt(fmt(name, :red), :bold)}} ]
      end

      if output.nil? # i.e. on entry/exit point of activity
        return [ level, %{#{name}} ]
      end

      [ level, %{#{fmt( name, color_map[ signal_of(output.data) ] )}} ]
    end

    def fmt(line, style)
      return line unless style
      String.send(style, line)
    end

    def signal_of(entity_output)
      entity_klass = entity_output.is_a?(Class) ? entity_output : entity_output.class
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
