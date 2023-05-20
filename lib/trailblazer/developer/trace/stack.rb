module Trailblazer
  module Developer
    module Trace
      # The stack is a linear one-dimensional array. Per traced task two {Trace::Captured}
      # elements get pushed onto it (unless there's an Exception).
      class Stack
        def initialize(captureds=[], **options)
          @stack    = captureds
          @options  = options
        end

        def add!(snapshot, options)
          @options.merge!(options)

          @stack << snapshot
        end # TODO: do we like this options merging?

        # DISCUSS: re-introduce #<< with one arg?

        def to_a
          @stack
        end

        # DISCUSS: should the Stack maintain both the snapshot stack and additional
        #          data such as variable versions, or better have two separate objects?
        def to_h
          @options
        end
      end # Stack
    end
  end
end
