$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "trailblazer/developer"

require "minitest/autorun"
require "pp"

require "trailblazer/activity"
require "trailblazer/activity/testing"
require "trailblazer/activity/dsl/linear"
puts "Running in Ruby #{RUBY_VERSION}"

Trailblazer::Developer.config.logger = Logger.new($stdout, formatter: proc do |severity, datetime, progname, msg|
  "#{msg}\n"
end)

T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  Dev = Trailblazer::Developer
  include Trailblazer::Activity::Testing::Assertions
end
