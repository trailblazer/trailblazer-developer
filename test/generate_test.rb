require "test_helper"

require "json"

class GenerateTest < Minitest::Spec
  # a and b have {label} fields which are to be the ID in the generated structure.
  # End has label:"\"String\""
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
      target=:one>],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=:one,
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=:no_two?>],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=:no_two?,
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
      target="End.success">,
     #<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:new,
      target=:one>],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id="End.success",
    data={"stop_event"=>true}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=nil>]},
 stop_task_ids=["End.success"],
 start_task_ids=["Event-jtq9oxsj"]>
}

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
