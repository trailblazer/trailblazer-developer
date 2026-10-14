module Trailblazer
  module Developer
    module Trace
      module TaskWrap # FIXME: location, naming?
        module Resolver
          CONDITION = ->(node:, **) { node.options[:task_wrap] } # only apply changes/extend "task_wrap" nodes. NOTE: this is a concept from activity/dsl.
        end
      end

      @value_snapshooter = Trace::Snapshot::Value.build()
      singleton_class.attr_reader :value_snapshooter # NOTE: this is semi-private. # DISCUSS: do we want that?

      # {delimits: nil} means we're a Before.
      # FIXME: two Capture instances referring to "task_wrap.call_task" will use the same Hash key. test that explicitly.
      # FIXME: why not use circuit_options here and save the Id stuff?
      class Capture < Struct.new(:id, :delimits, :internal_id)
        # Created at runtime by WrapRuntime.
        def call(lib_ctx, flow_options, signal, **options) # DISCUSS: do we need to default snapshot_before? with canonical invoke?
          # NOTE: feel free to replace {Snapshot}.
          snapshot, new_versions = Snapshot.(lib_ctx, flow_options, signal, **options, id: id, delimits: delimits)

          # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
          flow_options[:stack].add!(self, snapshot, new_versions)

          return lib_ctx, flow_options, signal
        end
      end

      # FIXME: extract this.
      class Extension # TODO: use canonical Node::Extension or whatever we name it?!
        # Called through WrapRuntime::Runner, obviously at runtime.
        def self.call(id:, **)
          # we know we're receiving a NodeWrap::Id instance here.
          traced_id = id.to_sym # {id} is a NodeWrap::Id instance (in NodeWrap mode, not in taskWrap mode, omg).

          # produce ADDs
          [
            [:"task_wrap.capture_args",   Circuit::Node[capture_before = Capture.new(traced_id, nil, rand), Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}],   :before, :"task_wrap.call_task"],
            [:"task_wrap.capture_return", Circuit::Node[Capture.new(traced_id, capture_before), Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :after, nil], # append to the very end of tW.
          ]
        end

      end

      module Invoke
        module_function

        def add_extension_for_wrap_node_tracing(lib_ctx, flow_options, circuit_options, **)
          extensions = circuit_options.fetch(:extensions)

          trace_extension = Circuit::WrapRuntime.Extension(
            Circuit::WrapRuntime::Extension::NodeWrap::USER_CONDITION,
            adds: Extension
          ) # TODO: constant

          extensions += [
            Circuit::WrapRuntime::Extension::NodeWrap::EXTENSION,
            trace_extension,
          ]

          return lib_ctx, flow_options, circuit_options.merge(extensions: extensions)
        end

        def add_extension_for_application_tracing(lib_ctx, flow_options, circuit_options, **)
          extensions = circuit_options.fetch(:extensions)

          extension = Trailblazer::Circuit::WrapRuntime.Extension(
            Trailblazer::Developer::Trace::TaskWrap::Resolver::CONDITION,
            adds: Trailblazer::Developer::Trace::Extension
          )

          extensions += [extension]

          return lib_ctx, flow_options, circuit_options.merge(extensions: extensions)
        end

        def add_options_for_trace(lib_ctx, flow_options, circuit_options, **)
          flow_options_for_trace = {
            stack:              Trailblazer::Developer::Trace::Stack.new,
            value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
          }

          flow_options = flow_options_for_trace.merge(flow_options)

          return lib_ctx, flow_options, circuit_options#.merge(extensions: extensions)
        end
      end
    end # Trace
  end
end

