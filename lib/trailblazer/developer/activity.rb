module Trailblazer
  module Developer
    # Transforms an {Activity::Graph} into an abstract data structure that represents the graph via a
    # well-defined API. The goal is to decouple graph internals from the presentation layer.
    # The {Model} is usually passed into Renderer and Layouter, to render the bpmn:Diagram XML or JSON.
    #
    # It returns {Model} with {Task}s and {Flow}s.
    module Activity
      module Graph
        class << self
          Model = Struct.new(:id, :start_events, :end_events, :task, :sequence_flow)
          Task  = Struct.new(:id, :name, :options, :incoming, :outgoing)
          # DISCUSS: direction ATM is the "condition" for the BPMN rendering.
          Flow  = Struct.new(:id, :sourceRef, :targetRef, :direction)

          # @param Graph an object implementing the Activity::Graph interface
          # @return Model Generic representation of the graph, ready for rendering.
          def self.to_model(graph, id: "some-process") # rubocop:disable Metrics/AbcSize
            start_events = graph.find_all("Start.default") # FIXME. this is a static assumption.
            end_events   = graph.find_all { |node| graph.successors(node).size.zero? }
            tasks        = graph.find_all { |_node| true }
            tasks       -= start_events
            tasks       -= end_events

            # transform nodes into BPMN elements.
            start_events = start_events.collect do |evt|
              Task.new(evt[:id], evt[:id], evt, Incomings(graph, evt), Outgoings(graph, evt))
            end
            end_events = end_events.collect do |evt|
              Task.new(evt[:id], evt[:id], evt, Incomings(graph, evt), Outgoings(graph, evt))
            end
            tasks        = tasks.collect { |evt| Task.new(evt[:id], evt[:id], evt, Incomings(graph, evt), Outgoings(graph, evt)) }
            edges        = (start_events + end_events + tasks).collect { |task| [task.incoming, task.outgoing] }.flatten(2).uniq

            Model.new(id, start_events, end_events, tasks, edges)
          end

          private

          def Outgoings(graph, source)
            graph.successors(source).collect { |target, edge| Flow.new(edge[:id], source[:id], target[:id], edge[:_wrapped]) }
          end

          def Incomings(graph, target)
            graph.predecessors(target).collect { |source, edge| Flow.new(edge[:id], source[:id], target[:id], edge[:_wrapped]) }
          end
        end
      end
    end
  end
end
