require "test_helper"

require "json"

class GenerateTest < Minitest::Spec
  it "what" do
    json = File.read("./test/json/three.json")

    intermediate = Trailblazer::Developer::Generate.("elements" => JSON[json])

    require "pp"
    out = PP.pp(intermediate, "")
    out.must_equal %{#<struct Trailblazer::Activity::Schema::Intermediate
 wiring=
  {#<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="Event-jtq9oxsj",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target="a">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="a",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target="b">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="b",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target="c">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="c",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target="d">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="d",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target="EndEventTerminate-jtq9phpw">,
     #<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:new,
      target="a">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="EndEventTerminate-jtq9phpw",
    data={"stop_event"=>true}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=nil>]},
 stop_task_ids=["EndEventTerminate-jtq9phpw"],
 start_task_ids=["Event-jtq9oxsj"]>
}

    implementing = T.def_tasks(:a, :b, :c, :d)

    implementation = Class.new(Trailblazer::Activity::Implementation) do
      implement intermediate,
        # start: false,
        "a" => implementing.method(:a),
        "b" => implementing.method(:b),
        "c" => implementing.method(:c),
        "d" => {task: Trailblazer::Activity::TaskBuilder.method(:Binary).(implementing.method(:d)), outputs: {new: Trailblazer::Activity.Output(Trailblazer::Activity::Left, :new),
          success: Trailblazer::Activity.Output(Trailblazer::Activity::Right, :success)}, extensions: []},
        "EndEventTerminate-jtq9phpw" => {task: _end=Trailblazer::Activity.End(:success), outputs: {success: Trailblazer::Activity.Output(_end, :success)}, extensions: {}}
    end

    assert_process_for implementation.to_h, :success, %{
#<Start/:success>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}

    signal, (ctx, _) = implementation.([seq: []])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a, :b, :c, :d]}}
  end
end

=begin
// this will allow multiple activities in one "view":
{
  "Expense::Activity::Create": {
    // here we can store additional data about the activity etc

    // this is where the current top-level array goes:
    elements: [
      {
        linksTo: [

          {
            target: "..",
            semantic: "success",
            label: "this is a link with :new semantic" // :symbol_style is matched as semantic
          }
        ]
      }
    ]
  }
}
=end
