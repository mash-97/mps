# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:default_test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: "test:with_groups"
namespace :test do 
  desc "Run test task with specified groups of gems bundle"
  task :with_groups do 
    Rake::Task[:default_test].invoke
  end
end