# frozen_string_literal: true

# Auto-discovers and loads all command files from the commands/ directory.
# Adding a command = adding a file here; no other changes required.
Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].sort.each { |f| require f }
