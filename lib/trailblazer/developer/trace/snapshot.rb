module Trailblazer::Developer
  module Trace
    # WARNING:  the interfaces here are subject to change, we're still experimenting
    #           with the architecture of tracing, and a healthy balance of performance/memory
    #           and clean design.
    # A Snapshot comprises of data captured before of after a "step". This usually
    # includes a ctx snapshot, variable versions and a returned signal for after-step
    # snapshots.
    #
    # Note that {Before} and {After} are generic concepts know to Trace::Present and Debugger.
    #
    # Snapshot::After{
    #   signal: <End.Success>
    #   ctx_snapshot: Snapshot::Ctx{
    #     variable_versions: [:current_user, 0], [:model, 0]
    #   }
    # }
    class Snapshot < Struct.new(:task, :activity, :data)
      Before  = Class.new(Snapshot)
      After   = Class.new(Snapshot)

      # This is called from {Trace.capture_args} and {Trace.capture_return} in the taskWrap.
      def self.call(ctx_snapshooter, wrap_config, ((ctx, flow_options), circuit_options))
        # DISCUSS: grab the {snapshooter} here from flow_options, instead of in Trace.capture_args?
        changeset, new_versions = ctx_snapshooter.call(wrap_config, [[ctx, flow_options], circuit_options])

        snapshot = new( # either Before or After.
          wrap_config[:task],
          circuit_options[:activity],
          changeset
        ).freeze

        return snapshot, new_versions
      end

      # Serialize all ctx variables before {call_task}.
      # This is run just before {call_task}, after In().
      def self.before_snapshooter(wrap_ctx, ((ctx, flow_options), _))
        changeset, new_versions = snapshot_for(ctx, **flow_options)

        data = {
          ctx_variable_changeset: changeset,
        }

        return data, new_versions
      end

      # Serialize all ctx variables at the very end of taskWrap, after Out().
      def self.after_snapshooter(wrap_ctx, _)
        snapshot_before             = wrap_ctx[:snapshot_before]
        returned_ctx, flow_options  = wrap_ctx[:return_args]

        changeset, new_versions = snapshot_for(returned_ctx, **flow_options)

        data = {
          ctx_variable_changeset: changeset,
          signal:                 wrap_ctx[:return_signal],
          snapshot_before:        snapshot_before, # add this so we know who belongs together.
        }

        return data, new_versions
      end

      def self.snapshot_for(ctx, value_snapshooter:, stack:, **)
        variable_versions = stack.variable_versions

        variable_versions.changeset_for(ctx, value_snapshooter: value_snapshooter) # return {changeset, new_versions}
      end

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
      module Ctx
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
      end # Ctx
    end
  end
end
