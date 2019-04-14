require 'trailblazer/activity'

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

    COLOR_MAP = Trailblazer::Developer.config.trace_color_map

    # Run {activity} with tracing enabled and inject a mutable {Stack} instance.
    # This allows to display the trace even when an exception happened
    def invoke(activity, (ctx, flow_options), *args)
      flow_options ||= {} # Ruby sucks.

      # this instance gets mutated with every step. unfortunately, there is
      # no other way in Ruby to keep the trace even when an exception was thrown.
      stack = Trailblazer::Activity::Trace::Stack.new

      begin
        _returned_stack, *returned = Trailblazer::Activity::Trace.invoke(
          activity,
          [
            ctx,
            flow_options.merge(stack: stack)
          ],
          *args
        )
        puts Trailblazer::Activity::Trace::Present.(stack, renderer: method(:renderer))

      rescue => exception
        puts Trailblazer::Activity::Trace::Present.(stack, renderer: method(:renderer))
        raise(exception)
      end

      returned
    end

    def renderer(task_node:, position:, tree:)
      if task_node[:output].nil? && tree[position.next].nil? # i.e. when exception raised
        return [ task_node[:level], %{#{fmt(fmt(task_node[:name], :red), :bold)}} ]
      end

      if task_node[:output].nil? # i.e. on entry/exit point of activity
        return [ task_node[:level], %{#{fmt(task_node[:name], COLOR_MAP.default)}} ]
      end

      [ task_node[:level], %{#{fmt(task_node[:name], COLOR_MAP[task_node[:output].data])}} ]
    end

    def fmt(line, style)
      String.send(style, line)
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
