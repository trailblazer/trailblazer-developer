require "test_helper"

class RenderContextTest < Minitest::Spec
  User = Struct.new(:id)

  it "renders table for ctx without any mutations" do
    # ctx without any mutations
    ctx = Trailblazer::Context({ current_user: User.new(1), params: { name: "John" } })
    output, _ = capture_io do
      Trailblazer::Developer::Render::Context.(ctx)
    end

    assert_equal output, %{
********** ctx **********
┌───────────────┬────────────────────────────────────────┐
│ key           │ value                                  │
├───────────────┼────────────────────────────────────────┤
│ :current_user ╎ #<struct RenderContextTest::User id=1> │
│ :params       ╎ {:name=>"John"}                        │
└───────────────┴────────────────────────────────────────┘

********** ctx mutations **********
┌─────┬───────┐
│ key │ value │
├─────┼───────┤
│     ╎       │
└─────┴───────┘
}

  end

  it "renders table for ctx with mutations" do
    ctx = Trailblazer::Context({ current_user: User.new(1), params: { name: "John" } })
    ctx[:say] = "something"
    ctx[:params] = { id: 1 }

    output, _ = capture_io do
      Trailblazer::Developer::Render::Context.(ctx)
    end

    assert_equal output, %{
********** ctx **********
┌───────────────┬────────────────────────────────────────┐
│ key           │ value                                  │
├───────────────┼────────────────────────────────────────┤
│ :current_user ╎ #<struct RenderContextTest::User id=1> │
│ :params       ╎ {:name=>"John"}                        │
└───────────────┴────────────────────────────────────────┘

********** ctx mutations **********
┌─────────┬─────────────┐
│ key     │ value       │
├─────────┼─────────────┤
│ :say    ╎ "something" │
│ :params ╎ {:id=>1}    │
└─────────┴─────────────┘
}
  end

  it "renders table for ctx with zoom on `:params`" do
    ctx = Trailblazer::Context({ current_user: User.new(1), params: { name: "John" } })
    ctx[:params][:embed] = ["user", "post"] 

    output, _ = capture_io do
      Trailblazer::Developer::Render::Context.(ctx, :params)
    end

    assert_equal output, %{
********** ctx **********
┌───────────────┬───────────────────────────────────────────┐
│ key           │ value                                     │
├───────────────┼───────────────────────────────────────────┤
│ :current_user ╎ #<struct RenderContextTest::User id=1>    │
│ :params       ╎ {:name=>"John", :embed=>["user", "post"]} │
└───────────────┴───────────────────────────────────────────┘

********** ctx mutations **********
┌─────┬───────┐
│ key │ value │
├─────┼───────┤
│     ╎       │
└─────┴───────┘

********** params **********
┌────────┬──────────────────┐
│ key    │ value            │
├────────┼──────────────────┤
│ :name  ╎ "John"           │
│ :embed ╎ ["user", "post"] │
└────────┴──────────────────┘
}
  end
end
