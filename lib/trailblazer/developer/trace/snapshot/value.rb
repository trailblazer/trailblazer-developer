module Trailblazer::Developer
  module Trace
    class Snapshot
      # {Value} serializes the variable value using with custom logic, e.g. {value.inspect}.
      # A series of matchers decide which snapshooter is used.
      class Value
        def initialize(matchers)
          @matchers = matchers
        end

        # DISCUSS: this could be a compiled pattern matching `case/in` block here.
        def call(name, value, **options)
          @matchers.each do |matcher, inspect_method|
            if matcher.(name, value, **options)
              return inspect_method.(name, value, **options)
            end
          end

          raise "no matcher found for #{name.inspect}" # TODO: this should never happen.
        end

        def self.default_variable_inspect(name, value, ctx:)
          value.inspect
        end

        def self.build
          new(
            [
              [
                ->(*) { true }, # matches everything
                method(:default_variable_inspect)
              ]
            ]
          )
        end
      end
    end
  end
end
