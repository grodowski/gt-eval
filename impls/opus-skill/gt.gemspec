Gem::Specification.new do |s|
  s.name        = "gt"
  s.version     = "0.1.0"
  s.summary     = "Stacked pull request manager"
  s.description = "A CLI for managing stacked pull requests, similar to Graphite."
  s.authors     = ["gt"]
  s.license     = "MIT"

  s.files       = Dir["lib/**/*.rb", "bin/*"]
  s.executables = ["gt"]

  s.required_ruby_version = ">= 3.0"

  s.add_dependency "cli-ui", "~> 2.7"
end
