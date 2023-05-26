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

      # The original snapshooter methods, used to reside in {Trace}.
      module Deprecated
        # Called in {#Captured}.
        # @private
        # This function will be removed and is here for benchmarking reasons, only.
        def self.default_input_data_collector(wrap_config, ((ctx, _), _)) # DISCUSS: would it be faster to access ctx via {original_args[0][0]}?
          data = {
            ctx_snapshot: ctx.to_h.collect { |k,v| [k, v.inspect] }.to_h,
          }

          return data, {}
        end

        # Called in {#Captured}.
        # @private
        # This function will be removed and is here for benchmarking reasons, only.
        def self.default_output_data_collector(wrap_config, ((ctx, _), _))
          returned_ctx, _ = wrap_config[:return_args]

          data = {
            ctx_snapshot: returned_ctx.to_h.collect { |k,v| [k, v.inspect] }.to_h,
            signal:       wrap_config[:return_signal]
          }

          return data, {}
        end
      end # Deprecated

      # This is run just before {call_task}, after In().
      def self.before_snapshooter(wrap_ctx, ((ctx, flow_options), _))
        variable_versions = flow_options[:stack].variable_versions

        changeset, new_versions = variable_versions.changeset_for(ctx)

        data = {
          ctx_variable_changeset: changeset,
        }

        return data, new_versions
      end

      # This is usually run at the very end of taskWrap, after Out().
      def self.after_snapshooter(wrap_ctx, _)
        returned_ctx, flow_options = wrap_ctx[:return_args]

        variable_versions = flow_options[:stack].variable_versions

        changeset, new_versions = variable_versions.changeset_for(returned_ctx)

        data = {
          ctx_variable_changeset: changeset,
          signal:                 wrap_ctx[:return_signal]
        }

        return data, new_versions
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
          def changeset_for(ctx)
            new_versions = []

            changeset_for_snapshot = ctx.collect do |name, value|
              value_hash = value.hash # DISCUSS: does this really always change when a deeply nested object changes?

              if (variable_versions = @variables[name]) && variable_versions.key?(value_hash) # TODO: test {variable: nil} value
                [name, value_hash, nil] # nil means it's an existing reference.
              else
                version = [name, value_hash, value.inspect]

                new_versions << version # FIXME: don't make it hard-coded {inspect}.
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
