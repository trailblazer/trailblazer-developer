require "test_helper"


require "trailblazer/developer"
require "trailblazer/diagram/bpmn"
require "trailblazer/circuit"

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
    puts Trailblazer::Diagram::BPMN.to_xml(blog)
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
