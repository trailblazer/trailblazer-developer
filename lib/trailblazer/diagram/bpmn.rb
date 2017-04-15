require "representable"
require "representable/xml"

require "trailblazer/developer/circuit"

module Trailblazer
  module Diagram
    module BPMN
      # Render an `Activity`'s circuit to a BPMN 2.0 XML `<process>` structure.
      def self.to_xml(activity, *args)
        # convert circuit to representable data structure.
        model = Trailblazer::Developer::Circuit.bla(activity, *args)

        # render XML.
        Representer::Definitions.new(Definitions.new(model)).to_xml
      end

      Definitions = Struct.new(:process, :diagram)

      # Representers for BPMN XML.
      module Representer
        class Task < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          # namespace "http://www.omg.org/spec/BPMN/20100524/MODEL"

          self.representation_wrap = :task # overridden via :as.

          property :id,   attribute: true
          property :name, attribute: true

          collection :outgoing, exec_context: :decorator
          collection :incoming, exec_context: :decorator

          def outgoing
            represented.outgoing.map(&:id)
          end

          def incoming
            represented.incoming.map(&:id)
          end
        end

        class SequenceFlow < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :sequenceFlow

          property :id,   attribute: true
          property :sourceRef, attribute: true, exec_context: :decorator
          property :targetRef, attribute: true, exec_context: :decorator
          property :direction, as: :conditionExpression

          namespace "bla"

          def sourceRef
            represented.sourceRef.id
          end

          def targetRef
            represented.targetRef.id
          end
        end

        class Process < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :process

          namespace "http://www.omg.org/spec/BPMN/20100524/MODEL"

          collection :start_events, as: :startEvent, decorator: Task, namespace: "bpmn"
          collection :end_events, as: :endEvent, decorator: Task,     namespace: "bpmn"
          collection :task, decorator: Task,                          namespace: "bpmn"
          collection :sequence_flow, decorator: SequenceFlow, as: :sequenceFlow, namespace: "bpmn"
        end

        class Diagram < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :diagram

          namespace "http://www.omg.org/spec/BPMN/20100524/DI"
        end

        class Definitions < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :"bpmn:definitions" # TODO: how to add a "self" namespace as if someone called to_xml(namespace: :bmpn) on us?

          property :process, decorator: Process, namespace: "bpmn"
          property :diagram, decorator: Diagram, namespace: "bpmndi"
        end
      end
    end
  end
end

