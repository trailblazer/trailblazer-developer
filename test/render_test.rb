require "test_helper"

class RenderCircuitTest < Minitest::Spec
  it "renders" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :a, Output(:failure) => Id("End.success")
      step :b
    end

    circuit = Trailblazer::Developer::Render::Circuit.(activity.to_h)
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
end
