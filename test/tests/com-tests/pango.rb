#!/usr/bin/env ruby

require 'rubygems'
require 'commander'


class MyApplication
  include Commander::Methods
  # include whatever modules you need

  def run
    program :name, 'pango'
    program :version, '1.0.2'
    program :description, 'pango is a modular dango'

    command :pingo do |c|
      c.syntax = 'pango pingo [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Pango::Commands::Pingo
        say "it's a pingo"
      end
    end

    command :pango do |c|
      c.syntax = 'pango pango [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Pango::Commands::Pango
      end
    end

    command :pungo do |c|
      c.syntax = 'pango pungo [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Pango::Commands::Pungo
      end
    end
    run!
  end
end

MyApplication.new.run
