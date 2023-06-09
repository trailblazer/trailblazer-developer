module Trailblazer::Developer
  module Trace
    class Snapshot
      # The original snapshooter methods, used to reside in {Trace}.
      # TODO: remove/
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
    end
  end
end
