require "test_helper"

class GraphTest < Minitest::Spec
  module A
    Memo = Class.new

    #:act
    class Memo::Update < Trailblazer::Activity::Railway
      step :find_model
      step :validate, Output(:failure) => End(:validation_error)
      step :save
      fail :log_error
    end
    #:act end
  end

  it do
    Memo = A::Memo

    #:find
    graph = Trailblazer::Developer::Introspect.Graph(Memo::Update)

    node = graph.find(:validate)
    #:find end

    # #:id
    # puts node.id.inspect #=> :validate
    # #:id end
    # #:task
    # puts node.task       #=> #Trailblazer::Activity::TaskBuilder::Task user_proc=validate>
    # #:task end
    #
    # #:outgoings
    # left, right = node.outgoings # returns array
    # #:outgoings end
    #
    # #:left-task
    # puts left.task #=> #Trailblazer::Activity::End semantic=:validation_error>
    # #:left-task end
    #
    # #:left
    # puts left.output.signal   #=> Trailblazer::Activity::Left
    # puts left.output.semantic #=> :failure
    # #:left end

    #:outputs
    outputs = node.outputs
    left = outputs[0] #=> output object
    #:outputs end

    _(node.id).must_equal :validate
    assert_equal CU.strip(node.task.inspect), %(#<Trailblazer::Activity::Circuit::Step::Binary:0x @step=#<Trailblazer::Activity::Circuit::Step::Option:0x @step=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:validate>>>)

    #:find-block
    node = graph.find { |node| node.task.class == Trailblazer::Activity::Circuit::Step::Binary }
    #:find-block end

    pp graph.termini
  end

end
