require "simplecov"
SimpleCov.start do
  add_group "Trailblazer-Developer", "lib"
  add_group "Tests", "test"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"

require "minitest/autorun"
require "test_xml/mini_test"

require "trailblazer/operation"

require "pp"
