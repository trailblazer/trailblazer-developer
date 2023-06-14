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
    end
  end
end
