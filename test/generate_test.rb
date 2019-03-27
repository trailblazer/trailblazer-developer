require "test_helper"

require "json"

class GenerateTest < Minitest::Spec
  it "what" do
    json = File.read("./test/json/three.json")

    intermediate = Trailblazer::Developer::Generate.("elements" => JSON[json])

    intermediate.inspect.must_equal %{
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
          }
        ]
      }
    ]
  }
}
=end
