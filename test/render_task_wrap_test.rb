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
    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, [:a])
    assert_inspect pipe, %{#<Class:xxx>
`-- a
    `-- task_wrap.call_task..............Method}

    #@ only In() set
    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, [:b])
    assert_inspect pipe, %{#<Class:xxx>
`-- b
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.init_hash.............................. ............................................. VariableMapping.initial_aggregate
    |   |-- input.add_variables.xxx[...]............... [:model]..................................... VariableMapping::AddVariables
    |   |-- input.add_variables.xxx[...]............... {:user=>:current_user}....................... VariableMapping::AddVariables
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.init_hash............................. ............................................. VariableMapping.initial_aggregate
        |-- output.default_output........................ ............................................. VariableMapping.default_output_ctx
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original}

    #@ only with Inject()
    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, [:c])
    assert_inspect pipe, %{#<Class:xxx>
`-- c
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.init_hash.............................. ............................................. VariableMapping.initial_aggregate
    |   |-- input.default_input.......................... ............................................. VariableMapping.default_input_ctx
    |   |-- inject.add_variables.passthrough.:current_user ............................................. VariableMapping::AddVariables
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.init_hash............................. ............................................. VariableMapping.initial_aggregate
        |-- output.add_variables.xxx[...].............. [:model]..................................... VariableMapping::AddVariables::Output
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

    pipe = Trailblazer::Developer::Render::TaskWrap.(activity, [:B, :b])
    assert_inspect pipe, %{#<Class:xxx>
`-- b
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.init_hash.............................. ............................................. VariableMapping.initial_aggregate
    |   |-- input.add_variables.xxx[...]............... [:current_user].............................. VariableMapping::AddVariables
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.init_hash............................. ............................................. VariableMapping.initial_aggregate
        |-- output.default_output........................ ............................................. VariableMapping.default_output_ctx
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original}
  end
end
