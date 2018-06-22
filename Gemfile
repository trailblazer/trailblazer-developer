source "https://rubygems.org"

# Specify your gem's dependencies in trailblazer-developer.gemspec
gemspec

gem "faraday"
gem "minitest-line"
# gem "rgl"

case ENV["GEMS_SOURCE"]
  when "local"
    gem "representable", path: "../representable"
    gem "trailblazer-activity", path: "../trailblazer-activity"
    gem "trailblazer-operation", path: "../trailblazer-operation"
  when "github"
    gem "representable", github: "trailblazer/trailblazer-activity"
    gem "trailblazer-activity", github: "trailblazer/trailblazer-activity"
    gem "trailblazer-operation", github: "trailblazer/trailblazer-operation"
  when "custom"
    eval_gemfile("GemfileCustom")
  else # use rubygems releases
end
