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

    File.write("berry.bpmn", xml)

    xml.must_equal File.read(File.dirname(__FILE__) + "/xml/operation.bpmn").chomp
  end
end
