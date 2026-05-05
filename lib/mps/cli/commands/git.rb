# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "git GITCOMMAND", "Run git commands inside storage_dir"
  def git(*commands)
    init
    begin
      git_command = if commands.first == "auto"
        auto_git_cmd
      elsif commands.first == "autocommit"
        "git add . && git commit -m \"$(date)\""
      elsif commands.size > 0
        cmds = commands.map { |c| c.include?(" ") ? "\"#{c}\"" : c }
        "git #{cmds.join(' ')}"
      else
        "git status"
      end
      inside(@config.storage_dir) { run git_command }
    rescue StandardError => e
      raise Thor::Error, e
    end
  end

  desc "autogit", "Auto stage, commit, pull and push"
  def autogit
    init
    begin
      inside(@config.storage_dir) { run auto_git_cmd }
    rescue StandardError => e
      raise Thor::Error, e
    end
  end

  desc "cmd COMMAND", "Run shell commands inside storage_dir"
  def cmd(*commands)
    init
    begin
      cmds = commands.map { |c| c.include?(" ") ? "\"#{c}\"" : c }
      inside(@config.storage_dir) { run cmds.join(" ") }
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
