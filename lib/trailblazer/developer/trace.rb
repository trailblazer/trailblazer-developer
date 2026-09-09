module Trailblazer
  module Developer
    module Trace
      @value_snapshooter = Trace::Snapshot::Value.build()
      singleton_class.attr_reader :value_snapshooter # NOTE: this is semi-private.

      # {delimits: nil} means we're a Before.
      # FIXME: two Capture instances referring to "task_wrap.call_task" will use the same Hash key. test that explicitly.
      class Capture < Struct.new(:id, :delimits)
        # Created at runtime by WrapRuntime.
        def call(lib_ctx, flow_options, signal, **options) # DISCUSS: do we need to default snapshot_before? with canonical invoke?
          snapshot, new_versions = Snapshot.build(lib_ctx, flow_options, signal, **options, id: id, delimits: delimits)

          # We try to be generic here in the taskWrap snapshooting code, where details happen in Snapshot::Before/After and Stack#add!.
          flow_options[:stack].add!(self, snapshot, new_versions)

          return lib_ctx, flow_options, signal
        end
      end

      # FIXME: extract this.
      class Extension # TODO: use canonical Node::Extension or whatever we name it?!
        # Called through WrapRuntime::Runner, obviously at runtime.
        def self.call(id:, **)
          # produce ADDs
          b=[
            [:"task_wrap.capture_args",   Circuit::Node[capture_before = Capture.new(id, nil), Circuit::Task::Adapter::LibInterface],   :before, :"task_wrap.call_task"],
            [:"task_wrap.capture_return", Circuit::Node[Capture.new(id, capture_before), Circuit::Task::Adapter::LibInterface], :after, nil], # append to the very end of tW.
          ]

          b[0][1].instance_variable_set(:@extended, true)
          b[1][1].instance_variable_set(:@extended, true)
          b
        end

      end
    end # Trace
  end
end

