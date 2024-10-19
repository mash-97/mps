# frozen_string_literal: true

require 'tty-logger'
module MPS
  class Logger 
    attr_reader :logger
    def initialize(log_file_path)
      @logger = TTY::Logger.new do |conf|
        conf.metadata = [:timestamp]
        conf.handlers = [
          [:stream, output: File.open(log_file_path, "a+")]
        ]
      end
    end
  end
end