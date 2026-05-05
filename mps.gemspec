# frozen_string_literal: true

require_relative "lib/mps/version"

Gem::Specification.new do |spec|
  spec.name          = "mps"
  spec.version       = MPS::VERSION
  spec.authors       = ["mash-97"]
  spec.email         = ["itzmashz@gmail.com"]

  spec.summary     = "Structured plain-text productivity CLI"
  spec.description = "MPS (MonoPsyches) is a terminal-based productivity system that stores " \
                     "tasks, notes, reminders, logs, and nested workflow structures in plain-text " \
                     ".mps files. It provides composable typed elements with optional arguments, " \
                     "hierarchical organization, natural-language date handling, full-text search, " \
                     "statistics, export tools, and git integration while keeping all data " \
                     "human-readable and portable."
  spec.homepage      = "https://github.com/mash-97/mps"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "thor",       "~> 1.3"
  spec.add_runtime_dependency "tty-editor", "~> 0.7.0"
  spec.add_runtime_dependency "chronic",    "~> 0.10.2"
  spec.add_runtime_dependency "cli-ui",     "~> 2.2"

  spec.add_development_dependency "rake",     "~> 13.2"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "fakefs",   "~> 2.5"
end
