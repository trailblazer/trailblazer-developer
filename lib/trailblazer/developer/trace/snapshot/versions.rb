module Trailblazer::Developer
  module Trace
    class Snapshot
      # Snapshot::Ctx keeps an inspected version of each ctx variable.
      # We figure out if a variable has changed by using `variable.hash` (works
      # even with deeply nested structures).
      #
      # Key idea here is to have minimum work at operation-runtime. Specifics like
      # figuring out what has changed can be done when using the debugger.
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
      #
      # DISCUSS: speed up by checking mutable, only?
      # DISCUSS: we currently only use this for testing.
      # DISCUSS: this has knowledge about {Stack} internals.
      #
      # This is for the "rendering" layer.
      # @private
      def self.snapshot_ctx_for(snapshot, variable_versions)
        variable_versions = variable_versions.instance_variable_get(:@variables)

        snapshot.data[:ctx_variable_changeset].collect do |name, hash, has_changed|
          [
            name,
            {
              value:        variable_versions[name][hash],
              has_changed:  !!has_changed,
            }
          ]
        end.to_h
      end

      # A table of all ctx variables, their hashes and serialized values.
      #
      #   {:current_user=>
      #     {3298051090906520533=>"#<TraceTest::User:0x000055b2e3424460 @id=1>",
      #      3764938782671692590=>"#<TraceTest::User:0x000055b2e33e45b8 @id=2>"},
      #    :params=>
      #     {2911818769466875657=>"{:name=>\"Q & I\"}",
      #      2238394858183550663=>"{:name=>\"Q & I\", :song=>{...}}"},
      #    :seq=>
      #     {-105020188158523405=>"[]",
      #      -2281497291400788995=>"[:authenticate]",
      #      150926802063554866=>"[:authenticate, :authorize]",
      #      3339595138798116233=>"[:authenticate, :authorize, :model]",
      #      -3395325862879242711=>
      #       "[:authenticate, :authorize, :model, :screw_params!]"},
      #    :model=>{348183403054247453=>"Object"}}
      class Versions
        def initialize
          @variables = {}
        end

        # DISCUSS: problem with changeset is, we have to go through variables twice.
        def changeset_for(ctx, value_snapshooter:)
          new_versions = []

          changeset_for_snapshot = ctx.collect do |name, value|
            # DISCUSS: do we have to call that explicitly or does Hash#[] do that for us, anyway?
            value_hash = value.hash # DISCUSS: does this really always change when a deeply nested object changes?

            if (variable_versions = @variables[name]) && variable_versions.key?(value_hash) # TODO: test {variable: nil} value
              [name, value_hash, nil] # nil means it's an existing reference.
            else
              value_snapshot = value_snapshooter.(name, value, ctx: ctx)

              version = [name, value_hash, value_snapshot]

              new_versions << version
              version
            end
          end

          return changeset_for_snapshot, new_versions
        end

        def add_changes!(new_versions)
          new_versions.each do |args|
            add_variable_version!(*args)
          end
        end

        # @private
        def add_variable_version!(name, hash, value)
          @variables[name] ||= {}

          @variables[name][hash] = value # i hate mutations.
        end

        def to_h
          @variables
        end
      end
    end # Snapshot
  end
end
