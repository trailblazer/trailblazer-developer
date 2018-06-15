require "test_helper"

# require 'rgl/adjacency'
# require 'rgl/topsort'

# dg=RGL::DirectedAdjacencyGraph[:a,:b, :a,:d, :b,:c, :b,:d, :c,:e, :c,:d, :d,:e, :e,:f, :e,:h, :f,:g, :f,:h, :g,:i, :g,:h, :h,:j,
#   :c,:l
# ]

# puts dg.topsort_iterator.to_a

class ActivityModelTest < Minitest::Spec
  Developer = Trailblazer::Developer

  class Create < Trailblazer::Operation
    step :a
    step :b
    step :bb
    failure :c
    step :d
    failure :e
    failure :f
  end

  require "representable/hash"
  class Model < Representable::Decorator
    include Representable::Hash

    class Task < Representable::Decorator
      include Representable::Hash
      property :id

      collection :outgoing do
        property :id
      end

      collection :incoming do
        property :id
      end
    end

    property :id

    collection :start_events, decorator: Task
    collection :end_events,   decorator: Task
    collection :task,         decorator: Task
    collection :sequence_flow do
      property :id
      property :sourceRef
      property :targetRef
    end
  end

  require "hash/bla.rb"

  it do
    graph = Create["__activity__"].graph

    model = Developer::Activity::Graph.to_model(graph)

    # expected = File.read(File.dirname(__FILE__) + "/xml/operation.bpmn").chomp

    Model.new(model).to_hash.must_equal __a # test/hash/bla.rb
  end
end
