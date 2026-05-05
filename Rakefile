# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :test do
  desc "Run all tests (alias used by CI)"
  task :with_groups do
    Rake::Task[:test].invoke
  end
end
