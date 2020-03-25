require 'hirb'

module Trailblazer
  module Developer
    module Trace

      module Focusable
        module_function

        # Get inspect of {focus_on.variables} or current {ctx}
        def capture_variables_from(ctx, focus_on:, inspector: Trace::Inspector, **flow_options)
          # ctx keys to be captured, for example [:current_user, :model, ....]
          variables = (selected = focus_on[:variables]).any? ? selected : ctx.keys

          variables.each_with_object({}) do |variable, result|
            if variable.is_a?(Proc) # To allow deep key access from ctx
              result[:Custom]   = inspector.(variable.call(ctx), **flow_options)
            else
              result[variable]  = inspector.(ctx[variable], **flow_options)
            end
          end
        end

        # Generate Hirb's vertical table nodes from captured ctx of each step
        # |-- some step name
        # |   |-- ********** Input **********
        #    message: "WTF!"
        #        seq: []
        # |   `-- ********** Output **********
        #    message: "WTF!"
        #        seq: [:a]
        def tree_nodes_for(level, input:, output:, **options)
          # TODO: Reverting `Hash#compact` usage as it is not supported in Ruby <= 2.4
          # Once the support is droped, revert actual code with below and remove entity check.
          # input_output_nodes = { Input: input, Output: output }.compact.collect do |table_header, entity|

          input_output_nodes = { Input: input, Output: output }.collect do |table_header, entity|
            next unless entity
            next unless Array( entity.data[:focused_variables] ).any?

            table = vertical_table_for(entity.data[:focused_variables], table_header: table_header)
            Present::TreeNodes::Node.new(level + 1, table, input, output, options).freeze
          end

          input_output_nodes.compact
        end

        # @private
        def vertical_table_for(focused_variables, table_header:)
          patched_vertical_table.render(
            Array[ focused_variables ],
            description: nil,
            table_header: table_header, # Custom option, not from Hirb
          )
        end

        # Overrding `Hirb::Helpers::VerticalTable#render_rows` because there is no option
        # to customize vertical table's row header :(
        # We need it to print if given entity is Input/Output
        #
        # @private
        def patched_vertical_table
          table = Class.new(Hirb::Helpers::VerticalTable)

          table.send(:define_method, :render_rows) do
            longest_header = Hirb::String.size (@headers.values.sort_by {|e| Hirb::String.size(e) }.last || '')
            stars = "*" * [(longest_header + (longest_header / 2)), 3].max

            @rows.map do |row|
              "#{stars} #{@options[:table_header]} #{stars}\n" +
                @fields.map{ |f| "#{Hirb::String.rjust(@headers[f], longest_header)}: #{row[f]}" }.join("\n")
            end
          end

          table
        end
      end
    end
  end
end
