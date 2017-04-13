require 'securerandom'

module Trailblazer
  module Developer
    # Transforms a circuit into a debugging data structure that can be passed into
    # a representer to render the bpmn:Diagram XML.
    module Circuit
      Task = Struct.new(:id, :name, :outgoing, :incoming)
      Flow = Struct.new(:id, :sourceRef, :targetRef)

      Model = Struct.new(:start_events, :end_events, :task, :sequence_flow)

      module_function
      def bla(activity)
        circuit  = activity.circuit
        flow_map = FlowMap.new
        task_map = TaskMap.new

        map, stop_events, debug = circuit.to_fields

        # Register all end events.
        end_events = stop_events.collect { |evt| task_map[evt, debug[evt] || evt] }

        map.each do |task, connections|
          id = debug[task] || task.to_s

          _task = task_map[task, id]
          # Outgoing
          _task.outgoing = map[task].collect { |direction, target| flow_map[_task, direction, task_map[target, debug[target]]] }

          # Incoming. Feel free to improve this!
          _task.incoming = map.collect { |source, hsh| hsh.find_all { |direction, target| target==task }
            .collect { |direction, target| [direction, source] } }.flatten.each_cons(2)
            .collect { |direction, source| flow_map[task_map[source, debug[source]], direction, _task] }
        end

        start_events = [task_map[activity[:Start], nil]] # horrible API.

        model = Model.new(start_events, [], task_map.values-start_events, flow_map.values)
      end

      class FlowMap < Hash
        def [](source, direction, target)
          key = [source.id, direction, target.id]

          super(key) or self[key] = Flow.new(Circuit.get_id("Flow"), source, target)
        end
      end

      class TaskMap < Hash
        def [](step, name)
          key = step

          super(key) or self[key] = Task.new(Circuit.get_id("Task"), name, [], [])
        end
      end

      def get_id(prefix)
        "#{prefix}_#{SecureRandom.hex[0..8]}"
      end
    end
  end
end
