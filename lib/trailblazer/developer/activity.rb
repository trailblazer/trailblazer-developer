require 'securerandom'

module Trailblazer
  module Developer
    # Transforms a circuit into a debugging data structure that can be passed into
    # a representer to render the bpmn:Diagram XML.
    #
    # It returns {Model} with {Task}s and {Flow}s.
    #
    # @note This structure is not necessarily limited to BMPN exports.
    module Activity
      Model = Struct.new(:id, :start_events, :end_events, :task, :sequence_flow)
      Task  = Struct.new(:id, :name, :options, :outgoing, :incoming)
      Flow  = Struct.new(:id, :sourceRef, :targetRef, :direction) # DISCUSS: direction ATM is the "condition" for the BPMN rendering.

      module_function
      def model_from(activity)
        graph  = activity.graph

        start_events = graph.find_all([:Start, :default]) # FIXME.
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

        return Model.new("process-fixme", start_events, end_events, tasks, edges), graph
      end
    end
  end
end
