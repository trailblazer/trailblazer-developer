$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"
require "trailblazer/core"

require "minitest/autorun"
require "pp"

# require "trailblazer/invoke" # FIXME: remove me, this should be done on library level.

# require "trailblazer/activity/dsl"
require "trailblazer/core"
puts "Running in Ruby #{RUBY_VERSION}"

require "trailblazer/activity"
