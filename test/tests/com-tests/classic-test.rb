#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'

  program :name, 'classic'
  program :version, '0.0.1'
  program :description, 'its a classic commander program'

command :classy do |c|
  c.syntax = 'classic classy [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--some-switch', 'Some switch that does something'
  c.action do |args, options|
    # Do something or c.when_called Classic::Commands::Classy
    say("we are what we are")
  end
end

command :flassy do |c|
  c.syntax = 'classic flassy [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--some-switch', 'Some switch that does something'
  c.command :flash do |cc|
    cc.syntax = "classic flassy flash"
    cc.summary = "clasic flash"

    cc.action do |args, opts|
      puts("this is inside flash act: #{args.to_s}, #{opts.to_s}")
    end
  end
  # c.action do |args, options|
    # Do something or c.when_called Classic::Commands::Flassy
   #  puts("this is inside the flassy")
 #  end
end

command :mlassy do |c|
  c.syntax = 'classic mlassy [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--some-switch', 'Some switch that does something'
  c.action do |args, options|
    # Do something or c.when_called Classic::Commands::Mlassy
  end
end

