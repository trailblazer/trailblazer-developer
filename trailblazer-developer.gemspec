lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "trailblazer/developer/version"

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-developer"
  spec.version       = Trailblazer::Version::Developer::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = "Developer tools for Trailblazer."
  spec.description   = "Developer tools for Trailblazer: debugger, tracing, visual editor integration."
  spec.homepage      = "http://trailblazer.to"
  spec.license       = "LGPL-3.0"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "trailblazer-activity", ">= 0.11.0", "< 1.0.0"
  spec.add_dependency "trailblazer-activity-dsl-linear"
  spec.add_dependency "representable"
  spec.add_dependency "hirb"
  spec.add_dependency "dry-configurable", "~> 0.11"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-line"
  spec.add_development_dependency "rake"
end
