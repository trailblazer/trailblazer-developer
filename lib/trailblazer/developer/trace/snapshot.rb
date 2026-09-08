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
    class Snapshot < Struct.new(:task, :data)
      # This is called from {Trace.capture_args} and {Trace.capture_return} in the taskWrap.
      def self.build(lib_ctx, flow_options, signal, id:, **options)
        # DISCUSS: grab the {snapshooter} here from flow_options, instead of in Trace.capture_args?
        changeset, new_versions = snapshoot(lib_ctx, flow_options, signal, **options) # TODO: apply LibInterface.

        snapshot = new(
          id,
          changeset,
        ).freeze

        return snapshot, new_versions
      end

      # Serialize all ctx variables before {call_task}.
      # This is (per configuration) run just before {call_task}, after In(). and after Out().
      def self.snapshoot(lib_ctx, flow_options, signal, target_ctx:, **)
        changeset, new_versions = snapshot_for(target_ctx, **flow_options)

        data = {
          ctx_variable_changeset: changeset,
          signal: signal
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
