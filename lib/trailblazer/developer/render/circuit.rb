module Trailblazer
  module Developer
    module Render
      module Circuit
        module_function

        def call(circuit, width: 90)
          # FIXME: use Introspect.

          cells = circuit.flow_map.collect do |id, connections|
            [
              id,
              connections.is_a?(Trailblazer::Circuit::Resolver::Fixed) ? nil : render_next_steps(extract_next_steps(connections))
            ]
          end

          content = cells.collect { |id, nexts|
            "│" + id.to_s.rjust(width - 60, " ") + " " + nexts.to_s.ljust(width - 30, " ") + " │"
          }.join("\n")

          top_margin    = "┌" + "".rjust(width - 2, "─") + "┐"
          bottom_margin = "└" + "".rjust(width - 2, "─") + "┘"

          return "#{top_margin}\n#{content}\n#{bottom_margin}"
        end

        def extract_next_steps(connections)
          connections.collect do |signal, (next_step_id, _)|
            [signal, next_step_id]
          end
        end

        # FIXME: Resolver::Conditional

        def render_next_steps(connections)
          reset = "\e[0m"
          colors = {
            Trailblazer::Activity::Right => "\e[32m",
            Trailblazer::Activity::Left => "\e[33m",
            nil => "",
          }

          arrow = "→"
          arrow = "➜"
          arrow = "▶" # ⎔

          sort_by = [Activity::Right, Activity::Left]
          connections = connections.sort do |(signal, next_step_id), b| # TODO: well yeah, this is pretty basic.
            sort_by.index(signal)
          end

          connections.collect do |signal, next_step_id|
            "#{colors[signal]}#{arrow} #{next_step_id}#{reset}"
          end.join(" ")
        end
      end
    end
  end
end
