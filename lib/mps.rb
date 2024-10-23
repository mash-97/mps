# frozen_string_literal: true

require "yaml"
require "logger"
require "chronic"
require "tty-editor"
require "strscan"
require_relative "mps/version"
require_relative "mps/mps"

ir "mps/constants"
ir "mps/config"
ir "mps/interpolators/interpolators"
ir "mps/elements/elements"
ir "mps/engines/engines"
ir "cli/mps"
module MPS
  class Error < StandardError; end
  # Your code goes here...
end
