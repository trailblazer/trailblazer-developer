require "test_helper"

class RenderTaskWrapTest < Minitest::Spec
  it "what" do
     activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, In() => [:model], In() => [:current_user]
    end

    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, id: :a)
    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, id: :b)
    assert_equal pipe, %{}
  end
end
