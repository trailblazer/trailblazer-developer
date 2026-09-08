$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/circuit"
require "trailblazer/activity/dsl"
require "trailblazer/activity"

require "trailblazer/developer"
require "trailblazer/core"

require "minitest/autorun"
require "pp"

# require "trailblazer/invoke" # FIXME: remove me, this should be done on library level.

require "trailblazer/core"

Minitest::Spec.class_eval do
  include Trailblazer::Core::Utils::AssertRun
  include Trailblazer::Core::Utils::AssertEqual

  T = Trailblazer::Core
end
