# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "yard"

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

namespace :yard do 
  desc "Generate yard docs"
  YARD::Rake::YardocTask.new(:generate) do |yt|
    yt.files = ["lib/**/*.rb"]
    yt.options = ["--private", "--output-dir", "yardocs"]
  end

  desc "Clean yard docs"
  task :clean do
    rm_rf "yardocs"
  end

  desc "Clean and Generate Yard Docs"
  task :clean_yard => [:clean, :generate]

  desc "Serve Clean Yard Docs"
  task :serve do
    Rake::Task["yard:clean_yard"].invoke
    sh "yard server --reload"
  end
end