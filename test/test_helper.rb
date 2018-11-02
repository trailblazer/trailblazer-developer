$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"

require "minitest/autorun"


require "trailblazer/activity"
require "trailblazer/activity/testing"

T = Trailblazer::Activity::Testing
