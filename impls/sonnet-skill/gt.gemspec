require_relative "lib/gt/version"

Gem::Specification.new do |spec|
  spec.name          = "gt"
  spec.version       = GT::VERSION
  spec.authors       = ["gt"]
  spec.summary       = "Stacked pull request manager"
  spec.description   = "A CLI tool for managing stacked pull requests like Graphite"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "bin/*"]
  spec.bindir        = "bin"
  spec.executables   = ["gt"]

  spec.add_dependency "cli-ui", "~> 2.7"
end
