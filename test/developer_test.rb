require "test_helper"


require "trailblazer/developer"
require "trailblazer/circuit"

require "representable"
require "representable/xml"





module Event
  class Start < Representable::Decorator
    include Representable::XML
    self.representation_wrap = :startEvent

    property :id, attribute: true
    collection :outgoing
  end
end

module Activity
  class Task < Representable::Decorator
    include Representable::XML
    self.representation_wrap = :task

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
end

class SequenceFlow < Representable::Decorator
  include Representable::XML
  self.representation_wrap = :SequenceFlow

  property :id,   attribute: true
  property :sourceRef, attribute: true, exec_context: :decorator
  property :targetRef, attribute: true, exec_context: :decorator

  def sourceRef
    represented.sourceRef.id
  end

  def targetRef
    represented.targetRef.id
  end
end

Start = Struct.new(:id, :outgoing)

class Model < Representable::Decorator
  include Representable::XML
  self.representation_wrap = false

  collection :task, decorator: Activity::Task
  collection :sequence_flow, decorator: SequenceFlow
end


# puts Event::Start.new(start).to_xml

class DiagramXMLTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(*) { snippet }
    Next    = ->(*) { snippet }
    Comment = ->(*) { snippet }
  end

  let(:blog) do
    Circuit::Activity(id: "blog.read/next", Blog::Read=>:Read, Blog::Next=>:Next, Blog::Comment=>:Comment) { |evt|
      {
        evt[:Start]  => { Circuit::Right => Blog::Read },
        Blog::Read => { Circuit::Right => Blog::Next },
        Blog::Next => { Circuit::Right => evt[:End], Circuit::Left => Blog::Comment },
        Blog::Comment => { Circuit::Right => evt[:End] }
      }
    }
  end


  it do
  start = Start.new(1, ["SequenceFlow_12"])
    Event::Start.new(start).to_xml.must_equal_xml %{
<startEvent id="1">
  <outgoing>SequenceFlow_12</outgoing>
</startEvent>
    }
  end

  it do
    require "trailblazer/developer/circuit"
    model = Trailblazer::Developer::Circuit.bla(blog.circuit)

    # raise model.task[0].inspect

    puts Model.new(model).to_xml
  end
end

#     <bpmn:startEvent id="StartEvent_1">
#       <bpmn:outgoing>SequenceFlow_1wsxfd0</bpmn:outgoing>
#     </bpmn:startEvent>
#     <bpmn:task id="Task_0vhpnru" name="write&#10;">
#       <bpmn:incoming>SequenceFlow_1wsxfd0</bpmn:incoming>
#       <bpmn:outgoing>SequenceFlow_0iwxv4o</bpmn:outgoing>
#     </bpmn:task>
#     <bpmn:sequenceFlow id="SequenceFlow_1wsxfd0" sourceRef="StartEvent_1" targetRef="Task_0vhpnru" />
# <bpmn:endEvent id="EndEvent_03m4k14">
#       <bpmn:incoming>SequenceFlow_1cisj8a</bpmn:incoming>
#     </bpmn:endEvent>
