require 'securerandom'

module Trailblazer
  module Developer
    # Transforms a circuit into a debugging data structure that can be passed into
    # a representer to render the bpmn:Diagram XML.
    module Circuit
      Task = Struct.new(:id, :name, :outgoing, :incoming)
      Flow = Struct.new(:id, :sourceRef, :targetRef, :direction) # DISCUSS: direction ATM is the "condition" for the BPMN rendering.

      Model = Struct.new(:start_events, :end_events, :task, :sequence_flow)

      module_function
      def bla(activity, id_generator: Id)
        circuit  = activity.circuit
        flow_map = FlowMap.new(id_generator)
        task_map = TaskMap.new(id_generator)

        map, stop_events, debug = circuit.to_fields

        # Register all end events.
        end_events = stop_events.collect { |evt| task_map[evt, debug[evt] || evt] }

        # make End events show up, too.
        map = map.merge( stop_events.collect { |evt| [evt, {}] }.to_h)

        map.each do |task, connections|
          id    = debug[task] || task.to_s
          puts "@@@@@ #{id.inspect}"
          _task = task_map[task, id]

          # Outgoing
          _task.outgoing = map[task].collect { |direction, target| flow_map[_task, direction, task_map[target, debug[target]]] }

          # Incoming. Feel free to improve this!
          _task.incoming = map.collect { |source, hsh| hsh.find_all { |direction, target| target==task }
            .collect { |direction, target| [direction, source] } }.flatten.each_slice(2)
            .collect { |direction, source| flow_map[task_map[source, debug[source]], direction, _task] }
        end

        start_events = [task_map[activity[:Start], nil]] # horrible API.

        model = Model.new(start_events, end_events, task_map.values-start_events-end_events, flow_map.values)
      end

      class Map < Hash
        def initialize(id_generator=Id)
          @id_generator = id_generator
        end
      end

      # TODO: make those two one.
      class FlowMap < Map
        def [](source, direction, target)
          key = [source.id, direction, target.id]

          super(key) or self[key] = Flow.new(@id_generator.("Flow"), source, target, direction)
        end
      end

      class TaskMap < Map
        def [](step, name)
          key = step

          super(key) or self[key] = Task.new(@id_generator.("Task"), name, [], [])
        end
      end

      Id = ->(prefix) { "#{prefix}_#{SecureRandom.hex[0..8]}" }
    end
  end
end
