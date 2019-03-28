lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "trailblazer/developer/version"

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-developer"
  spec.version       = Trailblazer::Developer::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = "Developer tools for Trailblazer."
  spec.description   = "Developer tools for Trailblazer: debugger, tracing, visual editor integration."
  spec.homepage      = "http://trailblazer.to/gems/trailblazer/developer.html"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop"

  spec.add_dependency "trailblazer-activity", "~> 0.8"
  spec.add_dependency "representable"
end
