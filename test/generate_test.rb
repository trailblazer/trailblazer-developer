require "test_helper"
require "json"
require "trailblazer/developer/client"

class GenerateTest < Minitest::Spec

  it "Generate.transform_from_hash generates a well-defined Struct" do
    json = File.read("./test/json/sign.json")

    structs = Trailblazer::Developer::Generate.transform_from_hash({}, hash: JSON[json])

    validate = structs.find { |struct| struct.id == "validate!" }

    validate.id.must_equal "validate!"
    validate.parent.must_equal "web.signup"
    validate.linksTo[0].target.must_equal "GatewayEventbased-jw9gp83r"
    validate.linksTo[0].message.must_be_nil
    validate.linksTo[1].target.must_equal "Start.default"
    validate.linksTo[1].message.must_equal true
  end

  it "Generate.call" do
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
    data={:type=>\"Event\"}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"validate\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"validate\",
    data={:type=>\"Task\"}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"save\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"save\",
    data={:type=>\"Task\"}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"success\">,
     #<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:failure,
      target=\"cleanup\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"success\",
    data={:type=>\"EndEventTerminate\"}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=nil>],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"cleanup\",
    data={:type=>\"Task\"}>=>
    [#<struct Trailblazer::Activity::Schema::Intermediate::Out
      semantic=:success,
      target=\"failure\">],
   #<struct Trailblazer::Activity::Schema::Intermediate::TaskRef
    id=\"failure\",
    data={:type=>\"EndEventTerminate\"}>=>
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
