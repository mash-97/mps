#!/usr/bin/env ruby

require 'rubygems'
require 'commander'

class MyApplication
  include Commander::Methods

  def run
    program :name, 'dango'
    program :version, '0.0.1'
    program :description, 'dango is an another awesome fully-glitched commander test'

    command :dingo do |c|
      c.syntax = 'dango dingo [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        say "#> from dingo args are: #{args.to_s}"
      end
    end

    command :dango do |c|
      c.syntax = 'dango dango [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|

      end
    end

    command :dungo do |c|
      c.syntax = 'dango dungo [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        c.when_called Dango::Commands::Dungo
      end
    end
  end
end
