# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'cli/ui'

module MPS
  module CLI
    class MPS < Thor
      include Thor::Actions
      class_option :verbose, type: :boolean, default: false
      class_option :config_path, type: :string, default: ::MPS::Constants::MPS_CONFIG_FILE, desc: "mps config file path"
      class_option :force, type: :boolean, default: false
      default_task :open

      def self.exit_on_failure?
        true
      end

      desc "version", "print version"
      def version
        say "mps (v#{::MPS::VERSION})"
      end

      desc "open DATESIGN", "Open mps file in editor, usually in Vim"
      def open(datesign="today")
        init()
        begin
          date = ::MPS.get_date(datesign)
          file_name = nil
          inside(@config.storage_dir) do
            file_name = resolve_mps_file(date) || ::MPS::Constants::MPS_NEW_FILE_NAME_GEN.call(date)
            @config.logger.info("Open MPS in text editor\n")
            written_bytes = ::MPS.open_editor(file_name)
            @config.logger.info("Done written Size: #{written_bytes} bytes\n")
            say_status :written, "#{written_bytes} bytes", :green
          end
        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end

      desc "git GITCOMMAND", "Run git commands inside the :storage_dir directory"
      def git(*commands)
        init()
        begin
          git_command = "git status"
          if commands.first=="auto"
            git_command = "git add . && git commit -m \"$(date)\" && git pull #{@config.git_remote} #{@config.git_branch} && git push #{@config.git_remote} #{@config.git_branch}"
          elsif commands.first=="autocommit"
            git_command = "git add . && git commit -m \"$(date)\""
          elsif commands.size>0
            commands = commands.each.collect{|c| c.include?(' ') ? "\"#{c}\"" : c }
            git_command = "git #{commands.join(' ')}"
          end
          inside @config.storage_dir do
            run git_command
          end

        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end

      desc "autogit", "Auto stage, commit, pull and push"
      def autogit()
        init()
        begin
          git_command = "git add . && git commit -m \"$(date)\" && git pull #{@config.git_remote} #{@config.git_branch} && git push #{@config.git_remote} #{@config.git_branch}"
          inside @config.storage_dir do 
            run git_command
          end
        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end
      
      desc "cmd COMMAND", "Run shell commands inside the :storage_dir directory"
      def cmd(*commands)
        init()
        begin
          commands = commands.each.collect{|c| c.include?(' ') ? "\"#{c}\"" : c }
          shell_command = "#{commands.join(' ')}"
          inside @config.storage_dir do
            run shell_command
          end

        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end

      desc "list [DATESIGN]", "List parsed elements from a .mps file"
      method_option :type, type: :string, aliases: "-t", desc: "Filter by element type (task, note, log, reminder)"
      def list(datesign = "today")
        init()
        begin
          date = ::MPS.get_date(datesign)
          file_name = nil
          inside(@config.storage_dir) do
            file_name = resolve_mps_file(date)
          end
          if file_name.nil?
            say "No file found for #{datesign}", :yellow
            return
          end

          element_classes = ::MPS::Elements.constants
                              .map { |k| ::MPS::Elements.const_get(k) }
                              .select { |x| x.class == Class }

          full_path = File.join(@config.storage_dir, file_name)
          elements  = ::MPS::Engines::MPS.parse_mps_file_to_elments_hash(full_path, element_classes)

          type_filter = options[:type]&.downcase
          shown = 0
          elements.each do |ref, el|
            type_name = el.respond_to?(:ecn) ? el.ecn.to_s.downcase : el.class::SIGNATURE_STAMP
            next if type_name == "mps"
            next if type_filter && type_name != type_filter
            say "[#{type_name}] #{el.body_str.strip}", :cyan
            shown += 1
          end
          say "(no elements found)", :yellow if shown == 0
        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end

      desc "append TYPE BODY", "Append a single element to today's file without opening Vim"
      method_option :tags, type: :string, desc: "Comma-separated tags (e.g. work,release)"
      method_option :at,   type: :string, desc: "Time argument for reminders"
      def append(type, *body_parts)
        init()
        begin
          body = body_parts.join(" ")
          args_str = build_args_str(type, options)
          date = ::MPS.get_date("today")
          file_name = nil
          inside(@config.storage_dir) do
            file_name = resolve_mps_file(date) || ::MPS::Constants::MPS_NEW_FILE_NAME_GEN.call(date)
          end
          full_path = File.join(@config.storage_dir, file_name)
          element_text = "\n@#{type}[#{args_str}]{\n  #{body}\n}\n"
          File.open(full_path, "a") { |f| f.write(element_text) }
          say_status :appended, "[#{type}] #{body}", :green
          @config.logger.info("Appended #{type} element to #{file_name}\n")
        rescue StandardError => err_msg
          raise Thor::Error, err_msg
        end
      end

      private
      def init()
        begin
          @config = load_config(options[:config_path], force: options[:force])
        rescue StandardError => err_msg
          say_status "error", "failed to initialize"
          raise Thor::Error, err_msg
        end
      end

      def load_config(config_path, force: false)
        if File.exist?(config_path) and not force
          return ::MPS::Config.new(**load_tangible_config_hash(config_path))
        end
        ::MPS::Config.init(config_path)
        return ::MPS::Config.new(**load_tangible_config_hash(config_path))
      end

      def load_tangible_config_hash(config_path)
        conf_hash = ::MPS::Config.load_conf_hash(config_path)
        if not Dir.exist?(conf_hash[:storage_dir])
          say_status "mps storage directory", "not found: #{conf_hash[:storage_dir]}", :yellow
          empty_directory conf_hash[:storage_dir]
        end
        if not Dir.exist?(conf_hash[:mps_dir])
          say_status "mps directory", "not found #{conf_hash[:mps_dir]}", :yellow
          empty_directory(conf_hash[:mps_dir])
        end
        if not File.exist?(conf_hash[:log_file])
          say_status "log file", "not found #{conf_hash[:log_file]}", :yellow
          create_file conf_hash[:log_file]
        end
        return conf_hash
      end

      def resolve_mps_file(date)
        inside(@config.storage_dir) do
          entries = Dir["**/#{date.strftime('%Y%m%d')}*\.#{::MPS::Constants::MPS_EXT}"].grep(::MPS::Constants::MPS_FILE_NAME_REGEXP)
          if entries.length == 0
            return nil
          elsif entries.length == 1
            return entries.first
          else
            return ::CLI::UI::Prompt.ask("#{entries.size} files found: ") do |handler|
              entries.each { |entry| handler.option(entry) { |s| s } }
            end
          end
        end
      end

      def build_args_str(type, opts)
        parts = []
        parts << "at: #{opts[:at]}" if opts[:at]
        parts << opts[:tags] if opts[:tags]
        parts.join(", ")
      end
    end
  end
end
