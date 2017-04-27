require "test_helper"


require "trailblazer/developer"
require "trailblazer/diagram/bpmn"
require "trailblazer/circuit"

class DiagramXMLTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class Id
    def initialize
      @count = 0
    end

    def call(name)
      "#{name}_#{@count += 1}"
    end
  end

  module Blog
    Read    = ->(*) { snippet }
    Next    = ->(*) { snippet }
    Comment = ->(*) { snippet }
  end

  require "trailblazer/operation"
  class Create < Trailblazer::Operation
    step :a
    step :b
    step :bb
    failure :c
    step :d
    failure :e
    failure :f
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
    puts xml = Trailblazer::Diagram::BPMN.to_xml(Create["__activity__"], Create["__sequence__"], id_generator: Id.new)
    # File.write("/home/nick/projects/wushi/app/berry.bpmn", xml)
    xml.must_equal File.read(File.dirname(__FILE__) + "/xml/operation.bpmn").chomp
  end

  it do
    puts xml = Trailblazer::Diagram::BPMN.to_xml(blog, id_generator: Id.new)
    xml.must_equal %{<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI">
  <bpmn:process>
    <bpmn:startEvent id="Task_2" name="#&lt;Start: default {}&gt;">
      <bpmn:outgoing>Flow_4</bpmn:outgoing>
    </bpmn:startEvent>
    <bpmn:endEvent id="Task_1" name="#&lt;End: default {}&gt;">
      <bpmn:incoming>Flow_7</bpmn:incoming>
      <bpmn:incoming>Flow_10</bpmn:incoming>
    </bpmn:endEvent>
    <bpmn:task id="Task_3" name="Read">
      <bpmn:outgoing>Flow_6</bpmn:outgoing>
      <bpmn:incoming>Flow_4</bpmn:incoming>
    </bpmn:task>
    <bpmn:task id="Task_5" name="Next">
      <bpmn:outgoing>Flow_7</bpmn:outgoing>
      <bpmn:outgoing>Flow_9</bpmn:outgoing>
      <bpmn:incoming>Flow_6</bpmn:incoming>
    </bpmn:task>
    <bpmn:task id="Task_8" name="Comment">
      <bpmn:outgoing>Flow_10</bpmn:outgoing>
      <bpmn:incoming>Flow_9</bpmn:incoming>
    </bpmn:task>
    <bpmn:sequenceFlow id="Flow_4" sourceRef="Task_2" targetRef="Task_3">
      <bpmn:conditionExpression>Trailblazer::Circuit::Right</bpmn:conditionExpression>
    </bpmn:sequenceFlow>
    <bpmn:sequenceFlow id="Flow_6" sourceRef="Task_3" targetRef="Task_5">
      <bpmn:conditionExpression>Trailblazer::Circuit::Right</bpmn:conditionExpression>
    </bpmn:sequenceFlow>
    <bpmn:sequenceFlow id="Flow_7" sourceRef="Task_5" targetRef="Task_1">
      <bpmn:conditionExpression>Trailblazer::Circuit::Right</bpmn:conditionExpression>
    </bpmn:sequenceFlow>
    <bpmn:sequenceFlow id="Flow_9" sourceRef="Task_5" targetRef="Task_8">
      <bpmn:conditionExpression>Trailblazer::Circuit::Left</bpmn:conditionExpression>
    </bpmn:sequenceFlow>
    <bpmn:sequenceFlow id="Flow_10" sourceRef="Task_8" targetRef="Task_1">
      <bpmn:conditionExpression>Trailblazer::Circuit::Right</bpmn:conditionExpression>
    </bpmn:sequenceFlow>
  </bpmn:process>
</bpmn:definitions>}
  end
end
