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

  graph = Create["__activity__"].graph
  # require "pp"
  # pp graph#.to_h

  # a = graph.find_all(:a)
  # puts graph.predecessors(a).inspect


  # # raise

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

    # token = "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJpZCI6NiwidXNlcm5hbWUiOiJkdWJlbCIsImVtYWlsIjoiZHViZWxAZHViZWwuZHViZWwifQ."
    # token = "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJpZCI6MywidXNlcm5hbWUiOiJhcG90b25pY2siLCJlbWFpbCI6Im5pY2tAdHJhaWxibGF6ZXIudG8ifQ."

    # require "faraday"
    # conn = Faraday.new(:url => 'http://localhost:3477')
    # response = conn.post do |req|
    #   req.url '/dev/v1/import'
    #   req.headers['Content-Type'] = 'application/json'
    #   req.headers["Authorization"] = token
    #   require "base64"

    #   req.body = %{{ "name": "Unagi", "xml":"#{Base64.strict_encode64(xml)}" }}
    # end

    # puts response.status.inspect

    xml.must_equal File.read(File.dirname(__FILE__) + "/xml/operation.bpmn").chomp
  end
end
