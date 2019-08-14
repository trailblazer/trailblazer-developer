require "test_helper"
require "json"
require "trailblazer/developer/client"

class GenerateTest < Minitest::Spec

  it "what" do
    # json = Dev::Client.import(id: 11, email: "apotonick@gmail.com", password: , host: "https://api.trailblazer.to", query: "?labels=save%3Ecleanup%3Efailure")
    # File.write("./test/json/validate-save-cleanup.json", json)

    # {id: "validate\n"} gets chomped on server
    json = File.read("./test/json/validate-save-cleanup.json")

    intermediate = Trailblazer::Developer::Generate.(JSON[json])

    out = PP.pp(intermediate, "")
    out.must_equal %{#<struct Trailblazer::Activity::Schema::Intermediate
 wiring=
  {#<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"Start.default\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"validate\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"validate\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"save\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"save\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"success\">,
     #<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:failure,
      target=\"cleanup\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"success\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=nil>],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"cleanup\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"failure\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"failure\",
    data={}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:failure,
      target=nil>]},
 stop_task_ids=[\"success\", \"failure\"],
 start_task_ids=[\"Start.default\"]>
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
