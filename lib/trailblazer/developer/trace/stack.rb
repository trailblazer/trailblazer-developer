module Trailblazer
  module Developer
    module Trace
      # The stack is a linear one-dimensional array. Per traced task two {Trace::Captured}
      # elements get pushed onto it (unless there's an Exception).
      #
      # The Stack object maintains the snapshots and the variable versions. It should probably
      # be named "Trace" :D
      # It is by design coupled to both Snapshot and Ctx::Versions.
      class Stack
        def initialize(snapshots = [], variable_versions = Snapshot::Ctx::Versions.new)
          @snapshots          = snapshots
          @variable_versions  = variable_versions # DISCUSS: I dislike the coupling here to Stack, but introducting another object comprised of Stack and VariableVersions seems overkill.
        end

        attr_reader :variable_versions # TODO: the accessor sucks. But I guess to_h[:variable_versions] is slower.

        def add!(snapshot, new_variable_versions)
          # variable_versions is mutated in the snapshooter, that's
          # why we don't have to re-set it here. I'm not a huge fan of mutating it
          # in a deeply nested scenario but everything else we played with added huge amounts
          # or runtime code.
          # @variable_versions = variable_versions
          @variable_versions.add_changes!(new_variable_versions)

          @snapshots << snapshot
        end # TODO: do we like this options merging?

        # DISCUSS: re-introduce #<< with one arg?

        def to_a
          @snapshots
        end
      end # Stack
    end
  end
end
