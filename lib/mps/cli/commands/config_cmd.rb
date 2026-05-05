# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "config [SUBCOMMAND]", "Manage MPS configuration (show | edit)"
  def config(subcommand = "show")
    init
    case subcommand.to_s.downcase
    when "show"
      say set_color("MPS configuration", :white)
      say "  config file : #{options[:config_path]}"
      say "  mps_dir     : #{@config.mps_dir}"
      say "  storage_dir : #{@config.storage_dir}"
      say "  log_file    : #{@config.log_file}"
      say "  git_remote  : #{@config.git_remote}"
      say "  git_branch  : #{@config.git_branch}"
      say "  default_cmd : #{@config.default_command}"
      unless @config.type_aliases.empty?
        say "  aliases     : #{@config.type_aliases.map { |k, v| "#{k}→#{v}" }.join(', ')}"
      end
    when "edit"
      path = options[:config_path]
      say set_color("Opening #{path} in editor", :white)
      ::TTY::Editor.open(path)
    else
      say set_color("Usage: mps config [show|edit]", :yellow)
    end
  end
end
