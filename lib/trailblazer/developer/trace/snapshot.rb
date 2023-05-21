module Trailblazer::Developer
  module Trace
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
      def self.call(ctx_snapshooter, wrap_config, ((ctx, flow), circuit_options))
        collected_ctx_data, stack_options = ctx_snapshooter.call(wrap_config, [[ctx, flow], circuit_options])

        snapshot = new( # either Before or After.
          wrap_config[:task],
          circuit_options[:activity],
          collected_ctx_data
        ).freeze

        return snapshot, stack_options
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
        variable_versions = flow_options[:stack].to_h[:variable_versions]

        version_refs, variable_versions = Ctx.collect_ctx_variable_snapshots!(variable_versions, ctx)

        data = {
          ctx_variable_refs:  version_refs,
        }

        return data, {variable_versions: variable_versions}
      end

      # This is usually run at the very end of taskWrap, after Out().
      def self.after_snapshooter(wrap_ctx, _)
        returned_ctx, flow_options = wrap_ctx[:return_args]

        variable_versions = flow_options[:stack].to_h[:variable_versions]

        version_refs, variable_versions = Ctx.collect_ctx_variable_snapshots!(variable_versions, returned_ctx)

        data = {
          ctx_variable_refs:  version_refs,
          signal:             wrap_ctx[:return_signal]
        }

        return data, {variable_versions: variable_versions}
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
        def self.collect_ctx_variable_snapshots!(variable_versions, ctx)
          version_refs = ctx.collect do |key, value|
            variable_versions.add!(key, value)
          end

          return version_refs, variable_versions
        end

        # DISCUSS: we currently only use this for testing.
        # DISCUSS: this has knowledge about {Stack} internals.
        # @private
        def self.snapshot_ctx_for(snapshot, stack)
          variable_versions = stack.to_h[:variable_versions].to_h

          snapshot.data[:ctx_variable_refs].collect do |name, hash|
            [
              name,
              variable_versions[name][hash]
            ]
          end.to_h
        end

        class Versions
          def initialize()
            @variables = {}
          end

          def add!(name, value)
            value_hash = value.hash # DISCUSS: does this really always change when a deeply nested object changes?

            if ! @variables.key?(name)
              @variables[name] = {}
            end

            if ! @variables[name].key?(value_hash)
              @variables[name][value_hash] = value.inspect # FIXME: don't make it hard-coded {inspect}.
            end

            [name, value_hash].freeze # "Variable version"
          end

          def to_h
            @variables
          end
        end
      end # Ctx
    end
  end
end
