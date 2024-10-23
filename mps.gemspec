# frozen_string_literal: true

require_relative "lib/mps/version"

Gem::Specification.new do |spec|
  spec.name          = "mps"
  spec.version       = MPS::VERSION
  spec.authors       = ["mash-97"]
  spec.email         = ["itzmashz@gmail.com"]

  spec.summary       = "MPS (MonoPsyches)"
  spec.description   = "Manage MonoPsyches."
  spec.homepage      = "https://github.com/mash-97/mps"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_runtime_dependency "strscan", "~> 3.1"
  spec.add_runtime_dependency "thor", "~> 1.3"
  spec.add_runtime_dependency "tty-editor", "~> 0.7.0"
  spec.add_runtime_dependency "chronic", "~> 0.10.2"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "fakefs", "~> 2.5"
  spec.add_development_dependency "tmpdir", "~> 0.2.0"
  spec.add_development_dependency "yard", "~> 0.9.37"
  spec.add_development_dependency "rack", "~> 3.1"
  spec.add_development_dependency "webrick", "~> 1.8"
  spec.add_development_dependency "rackup", "~> 2.1"
  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
