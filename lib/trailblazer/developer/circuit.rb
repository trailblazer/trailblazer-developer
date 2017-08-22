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
        graph  = activity.graph

        start_events = graph.find_all([:Start, :default]) # FIXME.
        end_events   = graph.find_all { |node| graph.successors(node).size == 0 }
        tasks = graph.find_all { |node| true }
        tasks -= start_events
        tasks -= end_events
        edges        = graph.find_all { |node| true }.collect { |node| graph.successors(node).collect { |edge, node| edge } }.flatten(1)

        model = Model.new(start_events, end_events, tasks, edges)
      end

      Id = ->(prefix) { "#{prefix}_#{SecureRandom.hex[0..8]}" }
    end
  end
end
