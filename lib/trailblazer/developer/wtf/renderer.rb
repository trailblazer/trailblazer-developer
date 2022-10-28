module Trailblazer::Developer
  module Wtf

    module Renderer
      DEFAULT_COLOR_MAP = { pass: :green, fail: :brown }

      SIGNALS_MAP = {
        :'Trailblazer::Activity::Right' => :pass,
        :'Trailblazer::Activity::FastTrack::PassFast' => :pass,

        :'Trailblazer::Activity::Left' => :fail,
        :'Trailblazer::Activity::FastTrack::FailFast' => :fail,
      }

      module_function

      # {options} can be {style: {#<Captured::Input> => [:red, :bold]}}
      def call(tree:, debugger_node:, style: {}, **options)
        label = styled_label(tree, debugger_node, style: style, **options)

        [debugger_node.level, label]
      end

      def styled_label(tree, debugger_node, color_map:, **options)
        label = apply_style(debugger_node.label, debugger_node, **options)

        %{#{fmt(label, color_map[ signal_of(debugger_node) ])}}
      end

      def apply_style(label, debugger_node, style:, **)
        return label unless styles = style[debugger_node.captured_input]

        styles.each { |s| label = fmt(label, s) }
        label
      end

      def fmt(line, style)
        if line.is_a? Method
          line = "#<Method: #<Class:>.#{line.name}>"
        end
        return line unless style
        String.send(style, line)
      end

      def signal_of(task_node)
        entity_signal = task_node.captured_output.data[:signal]
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
      end
    end
  end
end
