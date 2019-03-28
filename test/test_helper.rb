$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"

require "minitest/autorun"


require "trailblazer/activity"
require "trailblazer/activity/testing"
require "trailblazer/activity/dsl/linear"

T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  Dev = Trailblazer::Developer
  include Trailblazer::Activity::Testing::Assertions
end
