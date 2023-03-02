require "test_helper"

class RenderCircuitTest < Minitest::Spec
  it "renders" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :a, Output(:failure) => Id("End.success")
      step :b
    end

    circuit = Trailblazer::Developer.render(activity.to_h)
    assert_equal circuit, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=a>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=b>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_equal Trailblazer::Developer.render(activity), circuit
  end

  it "accepts segments as second optional argument" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      sub_activity = Class.new(Trailblazer::Activity::Railway) do
        sub_activity = Class.new(Trailblazer::Activity::Railway) do
          step :params
        end

        step Subprocess(sub_activity), id: :params
      end

      step Subprocess(sub_activity), id: "model"
    end

    circuit = Trailblazer::Developer.render(activity, path: ["model", :params])
    assert_equal circuit, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=params>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=params>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end
end
