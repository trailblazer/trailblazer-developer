module Trailblazer::Developer
  module_function

  def wtf(activity, *args, **kws) # TODO: allow kws only as {ctx}.
    Wtf.call_with_canonical_invoke(activity, *args, **kws)
  end

  class << self
    alias wtf? wtf
  end

  module Wtf
    module_function

    def call_with_canonical_invoke(activity, options, canonical_invoke: activity.method(:__), **kws)
      raise if options.is_a?(Array) # FIXME: deprecate old signature?

      # we activate tracing/wtf behavior via {:adds_for_options_compiler}.
      canonical_invoke.(activity, options, **options_for_canonical_invoke(**kws)) # Call activity.__()
    end

    def options_for_canonical_invoke(adds_for_options_compiler: [], **kws) # TODO: parts can be a constant.
      {
        **kws,
        adds_for_options_compiler: [
          [Trailblazer::Invoke::Options::HeuristicMerge.build(Trailblazer::Developer::Trace.method(:invoke_options_compiler_step)), id: "developer.trace", append: nil], # DISCUSS: redundant, we should retrieve that from Trace.
          [Trailblazer::Invoke::Options::HeuristicMerge.build(method(:invoke_options_compiler_step)), id: "developer.wtf", append: nil]
        ] + adds_for_options_compiler,
      }
    end

    def invoke_options_compiler_step(*)
      {
        invoke_method: Trailblazer::Developer::Wtf.method(:invoke_with_rescue),
      }
    end

    # FIXME: this is a helper for canonical invoke options compiler steps.
    # DISCUSS: isn't there a cooler way to add those options *within* an options-compiler step?
    def options_for_invoke(circuit_options: {}, flow_options: {}, **options)
      wtf_options = Trailblazer::Developer::Trace.invoke_options_compiler_step(nil, nil)

      options.merge(
        invoke_method:    Trailblazer::Developer::Wtf.method(:invoke_with_rescue), # DISCUSS: could {:invoke_method} be part of {invoke_options_for}?
        circuit_options:  circuit_options.merge(wtf_options[:circuit_options]),
        flow_options:     flow_options.merge(wtf_options[:flow_options]),
      )
    end

    def invoke_with_rescue(activity, ctx, flow_options, circuit_options)
      present_options = circuit_options[:present_options] || {}

      local_present_options_block = ->(*) { {} }
      stack = flow_options.fetch(:stack) # DISCUSS: should we really use {fetch}?
      raise_exception = false

      begin
        # complete_stack, signal, (ctx, flow_options) = Trace.invoke(
        ctx, flow_options, signal = Trailblazer::Activity::TaskWrap.invoke( # DISCUSS: this won't work with the traditional WTF.(Activity)
          activity,
          ctx,
          flow_options,
          circuit_options
        )

        complete_stack = flow_options[:stack]
      rescue
        raise_exception = $! # TODO: will this show the very same stacktrace?

        exception_source  = Exception.find_exception_source(stack, $!)
        complete_stack    = stack

        local_present_options_block = ->(trace_nodes:, **) {
          exception_source_node = trace_nodes.reverse.find do |trace_node|
            trace_node.snapshot_after == exception_source || trace_node.snapshot_before == exception_source
          end

          {
            # we can hand in options per node, identified by their captured_input part.
            node_options: {
              exception_source_node => {data: {exception_source: true}}, # goes to {Debugger::Node.build}
            },
            style: {
              exception_source_node => [:red, :bold]
            },
          }
        }
      end

      # always render the trace.
      output, returned_args = Trace::Present.(
        complete_stack,
        renderer:   Wtf::Renderer,
        color_map:  Wtf::Renderer::DEFAULT_COLOR_MAP.merge(flow_options[:color_map] || {}),
        activity:   activity,
        **present_options,
        &local_present_options_block
      )

      puts output # TODO: allow other channels here, not only {#puts}.

      raise raise_exception if raise_exception
      return ctx, flow_options, signal, output, returned_args
    end

    module Exception
      def self.find_exception_source(stack, exception)
        # in 99%, exception_source is a {Snapshot::Before}.
        _exception_source = stack.to_a.last  # DISCUSS: in most cases, this is where the problem has happened.
                                                  #   However, what if an error happens in, say, an input filter? TODO: test this
      end
    end
  end
end
