#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'

program :name, 'test'
program :version, '0.0.1'
program :description, 'test nested commands'

class C
  def initialize(opts)
    puts("#C> opts: #{opts.inspect}, class: #{opts.ancestors}")
    @opts = opts
  end
  def call()
    puts("#C> should call opts[:name]")
    puts("#C> @opts[:name]: #{@opts[:name]} or #{@opts.name}")
  end
end

command :it do |c|
  c.syntax = 'test it [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--some-switch', 'Some switch that does something'
  c.option '--name NAME', String, "some name to show"
  c.action do |args, opts|
    puts("it#> args: #{args.to_s}, opts: #{opts}")
    C.new(opts).call()
  end
end

