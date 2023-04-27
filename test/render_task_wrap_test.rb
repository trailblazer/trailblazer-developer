require "test_helper"

class RenderTaskWrapTest < Minitest::Spec
  def assert_inspect(asserted, expected)
    assert_equal asserted.gsub(/0x\w+/, "xxx").gsub(/0.\d+/, "xxx"), expected
  end

  it "what" do
     activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b,
        In() => [:model],
        In() => {:user => :current_user}
      step :c,
        Inject() => [:current_user],
        Out() => [:model]
    end

    #@ no special tW
    node, activity, _ = Trailblazer::Developer::Introspect.find_path(activity, [:a])
    pipe = Trailblazer::Developer::Render::TaskWrap.render_for(activity, node)
    assert_inspect pipe, %{#<Trailblazer::Activity:xxx>
`-- a
    `-- task_wrap.call_task..............Method}

    #@ only In() set
    node, activity, _  = Trailblazer::Developer::Introspect.find_path(activity, [:b])
    pipe = Trailblazer::Developer::Render::TaskWrap.render_for(activity, node)
    assert_inspect pipe, %{#<Trailblazer::Activity:xxx>
`-- b
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.add_variables.In{:model}............... ............................................. VariableMapping::SetVariable
    |   |-- input.add_variables.In{:user>:current_user}.. ............................................. VariableMapping::SetVariable
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.default_output........................ ............................................. VariableMapping.default_output_ctx
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original}

    #@ only with Inject()
    node, activity, _  = Trailblazer::Developer::Introspect.find_path(activity, [:c])
    pipe = Trailblazer::Developer::Render::TaskWrap.render_for(activity, node)
    assert_inspect pipe, %{#<Trailblazer::Activity:xxx>
`-- c
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.default_input.......................... ............................................. VariableMapping.default_input_ctx
    |   |-- input.add_variables.Inject{:current_user}.... ............................................. VariableMapping::SetVariable::Conditioned
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.add_variables.Out{:model}............. ............................................. VariableMapping::SetVariable::Output
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original}

  end

  it "allows path to step/activity" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      sub_activity = Class.new(Trailblazer::Activity::Railway) do
        step :b, In() => [:current_user]
      end

      step :a
      step Subprocess(sub_activity), id: :B
    end

    node, activity, _  = Trailblazer::Developer::Introspect.find_path(activity, [:B, :b])
    pipe = Trailblazer::Developer::Render::TaskWrap.render_for(activity, node)
    assert_inspect pipe, %{#<Trailblazer::Activity:xxx>
`-- b
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.add_variables.In{:current_user}........ ............................................. VariableMapping::SetVariable
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.default_output........................ ............................................. VariableMapping.default_output_ctx
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original}
  end
end

puts %{
Create
`-- :validate
    |-- task_wrap.input...................................
    |   |-- input.add_variables.In{:params}...............
    |   |-- input.add_variables.In{:user>:current_user}...
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output..................................
        |-- output.add_variables.Out{:result}.............

}
