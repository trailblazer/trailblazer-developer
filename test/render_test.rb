require "test_helper"

require "trailblazer/developer/render/circuit"

class RenderCircuitTest < Minitest::Spec
  it "renders" do
    activity = Module.new do
      extend Trailblazer::Activity::Railway()
      # extend T.def_steps(:a, :b)

      step :a, Output(:failure) => "End.success"
      step :b
    end

    Trailblazer::Developer::Render::Circuit.(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=a>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=b>
 {Trailblazer::Activity::Left} => #<End/:success>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
  end
end
