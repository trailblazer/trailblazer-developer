module Trailblazer
  module Developer
    module Render
      module Context
        module_function

        def call(ctx, *args)
          wrapped_options, mutable_options = ctx.decompose

          render_table(wrapped_options, title: "ctx")
          render_table(mutable_options, title: "ctx mutations")

          args.each do |arg|
            render_table(ctx[arg], title: arg)
          end
        end

        # private
        def render_table(data, title: nil)
          puts "\n#{"*" * 10} #{title} #{"*" * 10}" if title

          unless data.any?
            puts Hirb::Helpers::UnicodeTable.render(
              [{ "key" => "", "value" => "" }],
              description: false,
            )
            return 
          end

          puts Hirb::Helpers::UnicodeTable.render(
            Array(data),
            headers: { 0 => "key", 1 => "value" },
            filters: { 0 => :inspect, 1 => :inspect },
            description: false,
          )
        end
      end
    end
  end
end
