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
          namespace "http://www.omg.org/spec/BPMN/20100524/MODEL"

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
          namespace "http://www.omg.org/spec/BPMN/20100524/MODEL"

          property :id,   attribute: true
          property :sourceRef, attribute: true, exec_context: :decorator
          property :targetRef, attribute: true, exec_context: :decorator
          property :direction, as: :conditionExpression

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

          collection :start_events, as: :startEvent, decorator: Task
          collection :end_events, as: :endEvent, decorator: Task
          collection :task, decorator: Task
          collection :sequence_flow, decorator: SequenceFlow, as: :sequenceFlow
        end

        class Diagram < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :diagram

          namespace "http://www.omg.org/spec/BPMN/20100524/DI"

          namespace "http://www.omg.org/spec/DD/20100524/DC" # dc
          namespace "http://www.omg.org/spec/DD/20100524/DI" # di
          namespace "http://www.w3.org/2001/XMLSchema-instance" # xsi
        end

        class Definitions < Representable::Decorator
          include Representable::XML
          include Representable::XML::Namespace
          self.representation_wrap = :definitions

          namespace "http://www.omg.org/spec/BPMN/20100524/MODEL"
          namespace_def bpmn: "http://www.omg.org/spec/BPMN/20100524/MODEL"
          namespace_def bpmndi: "http://www.omg.org/spec/BPMN/20100524/DI"

          property :process, decorator: Process
          # property :diagram, decorator: Diagram
        end

        # <bpmndi:BPMNShape id="_BPMNShape_Task_3" bpmnElement="Task_3">
        #   <dc:Bounds x="236" y="78" width="100" height="80" />
        # </bpmndi:BPMNShape>

        # module Diagram
        #   class Shape < Representable::Decorator
        #     include Representable::XML
        #     include Representable::XML::Namespace
        #     self.representation_wrap = :"BPMNShape"

        #     property :id
        #     property :bpmnElement
        #     property :bounds do
        #       self.representation_wrap = :"Bounds"
        #       namespace "http://www.omg.org/spec/DD/20100524/DC" # namespace_uri / uri_reference

        #       property :x,      attribute: true
        #       property :y,      attribute: true
        #       property :width,  attribute: true
        #       property :height, attribute: true
        #     end
        #   end
        # end

      end
    end
  end
end

