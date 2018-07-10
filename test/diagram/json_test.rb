require "test_helper"

class DiagramJsonTest < Minitest::Spec
  let(:model) { Trailblazer::Diagram::JSON::Model.new }
  let(:collaboration) do
    {id: 1, type: :participant, name: "name", process: "process"}
  end
  let(:process) do
    {id: 1, type: :start_event, name: "name", incoming: "incoming"}
  end
  let(:shape) { {id: 1, type: :start_event, bounce: bounce, waypoint: waypoints} }
  let(:bounce) { {x: 100, y: 200, width: 300, height: 400} }
  let(:waypoints) { [{x: 100, y: 100}, {x: 100, y: 200}] }

  it "#new" do
    assert_kind_of Struct, model
    assert_equal [], model[:collaboration]
    assert_equal [], model[:process]
    assert_equal [], model[:diagram][:shape]
  end

  describe "#add_collaboration" do
    it "successfully" do
      model.add_collaboration(collaboration)

      assert_equal 1, model[:collaboration].count
      assert_equal 1, model[:collaboration].first.id
      assert_equal :participant, model[:collaboration].first.type
      assert_equal "name", model[:collaboration].first.name
      assert_equal "process", model[:collaboration].first.process
      assert_nil model[:collaboration].first.source
      assert_nil model[:collaboration].first.target
    end

    it "raises type error when passing the wrong one" do
      assert_raises Trailblazer::Diagram::JSON::WrongType do
        model.add_collaboration(id: 1, type: :wrong)
      end
    end

    it "raises input error when not passing at least one of the required input" do
      assert_raises Trailblazer::Diagram::JSON::MissingInput do
        model.add_collaboration(id: 1, type: :participant)
      end
    end
  end

  describe "#add_process" do
    it "successfully" do
      model.add_process(process)

      assert_equal 1, model[:process].count
      assert_equal 1, model[:process].first.id
      assert_equal :start_event, model[:process].first.type
      assert_equal "name", model[:process].first.name
      assert_equal "incoming", model[:process].first.incoming
      assert_nil model[:process].first.outgoing
      assert_nil model[:process].first.source
      assert_nil model[:process].first.target
    end

    it "raises type error when passing the wrong one" do
      assert_raises Trailblazer::Diagram::JSON::WrongType do
        model.add_process(id: 1, type: :wrong)
      end
    end

    it "raises input error when not passing at least one of the required input" do
      assert_raises Trailblazer::Diagram::JSON::MissingInput do
        model.add_process(id: 1, type: :start_event)
      end
    end
  end

  describe "#add_shape" do
    it "successfully" do
      model.add_shape(shape)

      assert_equal 1, model[:diagram][:shape].count
      assert_equal 1, model[:diagram][:shape].first.id
      assert_equal :start_event, model[:diagram][:shape].first.type

      assert_equal 100, model[:diagram][:shape].first.bounce.x
      assert_equal 200, model[:diagram][:shape].first.bounce.y
      assert_equal 300, model[:diagram][:shape].first.bounce.width
      assert_equal 400, model[:diagram][:shape].first.bounce.height

      assert_equal 2, model[:diagram][:shape].first.waypoint.count
      assert_equal 100, model[:diagram][:shape].first.waypoint.first.x
      assert_equal 100, model[:diagram][:shape].first.waypoint.first.y
      assert_equal 100, model[:diagram][:shape].first.waypoint.last.x
      assert_equal 200, model[:diagram][:shape].first.waypoint.last.y
    end

    describe "allows to pass waypoints with hash" do
      let(:waypoints) { {x: 100, y: 200} }

      it "populates waypoint successfully" do
        model.add_shape(shape)

        assert_equal 1, model[:diagram][:shape].first.waypoint.count
        assert_equal 100, model[:diagram][:shape].first.waypoint.first.x
        assert_equal 200, model[:diagram][:shape].first.waypoint.first.y
      end
    end

    it "raises type error when passing the wrong one" do
      assert_raises Trailblazer::Diagram::JSON::WrongType do
        model.add_shape(id: 1, type: :wrong)
      end
    end

    it "raises input error when not passing at least one of the required input" do
      assert_raises Trailblazer::Diagram::JSON::MissingInput do
        model.add_shape(id: 1, type: :start_event)
      end
    end
  end

  it "#to_json" do
    model = Trailblazer::Diagram::JSON::Model.new
    model.add_collaboration(collaboration)
    model.add_process(process)
    model.add_shape(shape)

    json = {
      collaboration: [collaboration],
      process: [process],
      diagram: {shape: [shape]}
    }.to_json

    assert_equal json, Trailblazer::Diagram::JSON.to_json(model)
  end
end
