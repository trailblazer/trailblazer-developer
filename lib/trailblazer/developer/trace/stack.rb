module Trailblazer
  module Developer
    module Trace
      # The stack is a linear one-dimensional array. Per traced task two {Trace::Captured}
      # elements get pushed onto it (unless there's an Exception).
      class Stack
        def initialize(captureds=[])
          @stack = captureds
        end

        def <<(captured)
          @stack << captured
        end

        def to_a
          @stack
        end
      end # Stack
    end
  end
end
