module Trailblazer
  module Developer
    module Trace

      # This module does the inspection of given `ctx` with deep traversal.
      # It only gets called when focusing is going on (i.e. focus_on API).
      module Inspector
        module_function

        def call(value, default_inspector: method(:default_inspector), **)
          return hash_inspector(value, default_inspector: default_inspector) if value.is_a?(Hash)
          return array_inspector(value, default_inspector: default_inspector) if value.is_a?(Array)

          default_inspector.(value)
        end

        def hash_inspector(value, default_inspector:)
          Hash[
            value.collect do |key, nested_value|
              [key, call(nested_value, default_inspector: default_inspector)]
            end
          ]
        end

        def array_inspector(value, default_inspector:)
          value.collect do |nested_value|
            call(nested_value, default_inspector: default_inspector)
          end
        end

        # To avoid additional query that AR::Relation#inspect makes,
        # we're calling AR::Relation#to_sql to get plain SQL string instead.
        def activerecord_relation_inspector(value)
          { query: value.to_sql }
        end

        def default_inspector(value)
          if defined?(ActiveRecord) && value.is_a?(ActiveRecord::Relation)
            return activerecord_relation_inspector(value)
          end

          value.inspect
        end
      end

    end
  end
end
