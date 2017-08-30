module Trailblazer
  module Developer
    # Transforms an {Activity::Graph} into an abstract data structure that represents the graph via a
    # well-defined API. The goal is to decouple graph internals from the presentation layer.
    # The {Model} is usually passed into Renderer and Layouter, to render the bpmn:Diagram XML or JSON.
    #
    # It returns {Model} with {Task}s and {Flow}s.
    module Activity
      module Graph
        Model = Struct.new(:id, :start_events, :end_events, :task, :sequence_flow)
        Task  = Struct.new(:id, :name, :options, :outgoing, :incoming)
        Flow  = Struct.new(:id, :sourceRef, :targetRef, :direction) # DISCUSS: direction ATM is the "condition" for the BPMN rendering.

        # @param Graph an object implementing the Activity::Graph interface
        # @return Model Generic representation of the graph, ready for rendering.
        def self.to_model(graph, id: "some-process")
          start_events = graph.find_all("Start.default") # FIXME. this is a static assumption.
          end_events   = graph.find_all { |node| graph.successors(node).size == 0 }
          tasks        = graph.find_all { |node| true }
          tasks       -= start_events
          tasks       -= end_events
          edges        = graph.find_all { |node| true }.collect { |node| graph.successors(node).collect { |node, edge| edge } }.flatten(1)

          # transform nodes into BPMN elements.
          start_events = start_events.collect { |evt| Task.new( evt[:id], evt[:id], evt, graph.successors(evt).collect(&:last), graph.predecessors(evt).collect(&:last) ) }
          end_events   =   end_events.collect { |evt| Task.new( evt[:id], evt[:id], evt, graph.successors(evt).collect(&:last), graph.predecessors(evt).collect(&:last) ) }
          tasks        =        tasks.collect { |evt| Task.new( evt[:id], evt[:id], evt, graph.successors(evt).collect(&:last), graph.predecessors(evt).collect(&:last) ) }
          edges        = edges.collect { |edge| Flow.new( edge[:id], edge[:source][:id], edge[:target][:id], edge[:_wrapped] ) }

          Model.new(id, start_events, end_events, tasks, edges)
        end
      end
    end
  end
end
