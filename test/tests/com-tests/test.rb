#!/usr/bin/env ruby

require 'rubygems'
require 'commander'
require_relative 'tango'

Commander.configure do
  program :name, 'commando'
  program :version, '0.0.1'
  program :description, "it's a test for commander init"
end

include Commander::Methods
class Test 
  def run
    puts("#> inside run")
    command :dig do |c|
      c.syntax = 'commando dig [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        say "# Do something or c.when_called Commando::Commands::Dig"
        t = ask_editor 'previous data', 'vim'
        say "#> #{t}"
      end
      include Tango
    end

    command :dag do |c|
      c.syntax = 'commando dag [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Commando::Commands::Dag
        log "create", "path/to/file.rb"
      end
    end

    command :dug do |c|
      c.syntax = 'commando dug [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Commando::Commands::Dug
        uris = %w{
          https://vision-media.ca
          https://google.com
          https://yahoo.com
        }
        progress uris do |uri|
          res = open uri
          log "got", "#{res.size}"
        end
      end
    end

    command :pig do |c|
      c.syntax = 'commando pig [options]'
      c.summary = ''
      c.description = ''
      c.example 'description', 'command example'
      c.option '--some-switch', 'Some switch that does something'
      c.action do |args, options|
        # Do something or c.when_called Commando::Commands::Pig
      end
    end
  end
end


Test.new.run! if $0==__FILE__
