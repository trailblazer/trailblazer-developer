require "test_helper"

class RenderLinearTest < Minitest::Spec
  class Create < Trailblazer::Activity::Railway
    step :decide!
    pass :wasnt_ok!
    pass :was_ok!
    fail :return_true!
    fail :return_false!
    step :finalize!
  end

  it do
    Trailblazer::Developer::Render::Linear.(Create).must_equal %{[>decide!,>>wasnt_ok!,>>was_ok!,<<return_true!,<<return_false!,>finalize!]}
  end

  it "is aliased to `Developer.railway`" do
    Trailblazer::Developer::Render::Linear.(Create).must_equal Trailblazer::Developer.railway(Create)
  end

  it do
    Trailblazer::Developer::Render::Linear.(Create, style: :rows).must_equal %{
 1 ==============================>decide!
 2 ===========================>>wasnt_ok!
 3 =============================>>was_ok!
 4 <<return_true!========================
 5 <<return_false!=======================
 6 ============================>finalize!}
  end

  describe "step with only one output (happens with Nested)" do
    class Present < Trailblazer::Activity::Railway
      pass :ok!, outputs: {:success => Trailblazer::Activity::Output("signal", :success)}
    end

    it do
      Trailblazer::Developer::Render::Linear.(Present).must_equal %{[>>ok!]}
    end
  end
end
