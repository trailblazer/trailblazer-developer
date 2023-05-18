module Trailblazer::Developer
  module Trace

    # Snapshot keeps an inspected version of each ctx variable.
    # We figure out if a variable has changed by using `variable.hash` (works
    # even with deeply nested structures).
    #
    # By keeping "old" versions, we get three benefits.
    # 1. We only need to call {inspect} once on a traced variable. Especially
    #    when variables are complex structures or strings, this dramatically speeds
    #    up tracing, from same-ish to factor 5!
    # 2. The content sent to our debugger is much smaller which reduces network load
    #    and storage space.
    # 3. Presentation becomes simpler as we "know" what variable has changed.
    #
    # Possible problems: when {variable.hash} returns the same key even though the
    #                    data has changed.
    module Snapshot
      module_function

      def input_data_collector(wrap_ctx, ((ctx, flow_options), _))
        variable_versions = flow_options[:variable_versions]

        keys = ctx.keys

        ctx_variable_refs = ctx.collect do |key, value|
          _ref = variable_versions.add!(key, value)
        end

        {
          ctx_variable_refs: ctx_variable_refs
        }
      end

      def output_data_collector(wrap_ctx, args)
        input_data_collector(wrap_ctx, args)
          .merge(signal: wrap_ctx[:return_signal])
      end

      class Versions
        def initialize()
          @variables = {}
        end

        def add!(name, value)
          value_hash = value.hash # DISCUSS: does this really always change when a deeply nested object changes?

          if @variables.key?(name)
            existing_version = @variables[name][value_hash] and return existing_version
          end

          @variables[name] ||= {}
          @variables[name][value_hash] = value.inspect # FIXME: don't make it hard-coded {inspect}.

          [name, value_hash].freeze # "Ref"
        end
      end
    end
  end
end
