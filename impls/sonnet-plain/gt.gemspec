# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "gt"
  spec.version       = "0.1.0"
  spec.authors       = ["gt"]
  spec.summary       = "CLI tool for managing stacked pull requests"
  spec.description   = "Graphite-like stacked PR management for git workflows"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "bin/*", "*.gemspec", "Gemfile"]
  spec.bindir        = "bin"
  spec.executables   = ["gt"]

  spec.add_dependency "cli-ui", "~> 2.7"

  spec.add_development_dependency "minitest", "~> 5.0"
end
