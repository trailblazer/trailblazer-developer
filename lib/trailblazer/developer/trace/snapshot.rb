module Trailblazer::Developer
  module Trace
    # A Snapshot comprises of data captured before of after a "step". This usually
    # includes a ctx snapshot, variable versions and a returned signal for after-step
    # snapshots.
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

      def self.build(data_collector, wrap_config, ((ctx, flow), circuit_options))
        collected_data = data_collector.call(wrap_config, [[ctx, flow], circuit_options])

        new( # either Before or After.
          wrap_config[:task],
          circuit_options[:activity],
          collected_data
        ).freeze
      end

      # The original snapshooter methods, used to reside in {Trace}.
      module Deprecated
        # Called in {#Captured}.
        # @private
        # This function will be removed and is here for benchmarking reasons, only.
        def self.default_input_data_collector(wrap_config, ((ctx, _), _)) # DISCUSS: would it be faster to access ctx via {original_args[0][0]}?
          {
            ctx_snapshot: ctx.to_h.collect { |k,v| [k, v.inspect] }.to_h,
          }
        end

        # Called in {#Captured}.
        # @private
        # This function will be removed and is here for benchmarking reasons, only.
        def self.default_output_data_collector(wrap_config, ((ctx, _), _))
          returned_ctx, _ = wrap_config[:return_args]

          {
            ctx_snapshot: returned_ctx.to_h.collect { |k,v| [k, v.inspect] }.to_h,
            signal:       wrap_config[:return_signal]
          }
        end
      end # Deprecated

      # This is run just before {call_task}, after In().
      def self.before_snapshooter(wrap_ctx, ((ctx, flow_options), _))
        variable_versions = flow_options[:variable_versions]

        {
          ctx_variable_refs:  Ctx.collect_ctx_variable_snapshots!(variable_versions, ctx),
        }
      end

      # This is usually run at the very end of taskWrap, after Out().
      def self.after_snapshooter(wrap_ctx, _)
        returned_ctx, flow_options = wrap_ctx[:return_args]

        variable_versions = flow_options[:variable_versions]

        {
          ctx_variable_refs:  Ctx.collect_ctx_variable_snapshots!(variable_versions, returned_ctx),
          signal:             wrap_ctx[:return_signal]
        }
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
          ctx.collect do |key, value|
            variable_versions.add!(key, value)
          end
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
        end
      end # Ctx
    end
  end
end
