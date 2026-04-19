# frozen_string_literal: true

require_relative "lib/gt/version"

Gem::Specification.new do |spec|
  spec.name = "gt"
  spec.version = GT::VERSION
  spec.authors = ["gt"]
  spec.summary = "CLI for managing stacked pull requests"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "bin/*"]
  spec.bindir = "bin"
  spec.executables = ["gt"]

  spec.add_dependency "cli-ui", "~> 2.7"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
