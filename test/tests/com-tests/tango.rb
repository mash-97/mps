#!/usr/bin/env ruby

require 'rubygems'
require 'commander'


include Commander::Methods
module Tango
  command :tingo do |c|
    c.syntax = 'tango tingo [options]'
    c.summary = ''
    c.description = ''
    c.example 'description', 'command example'
    c.option '--some-switch', 'Some switch that does something'
    c.action do |args, options|
      # Do something or c.when_called Tango::Commands::Tingo
      say "this is tingo"
    end
  end

  command :tango do |c|
    c.syntax = 'tango tango [options]'
    c.summary = ''
    c.description = ''
    c.example 'description', 'command example'
    c.option '--some-switch', 'Some switch that does something'
    c.action do |args, options|
      # Do something or c.when_called Tango::Commands::Tango
    end
  end

  command :tungo do |c|
    c.syntax = 'tango tungo [options]'
    c.summary = ''
    c.description = ''
    c.example 'description', 'command example'
    c.option '--some-switch', 'Some switch that does something'
    c.action do |args, options|
      # Do something or c.when_called Tango::Commands::Tungo
    end
  end
end
