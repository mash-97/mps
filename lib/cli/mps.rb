# frozen_string_literal: true

require 'thor'
require 'yaml'

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
          mps_engine = ::MPS::Engines::MPS.new(@config)
          written_bytes = mps_engine.mps_open(datesign)
          say_status :written, "#{written_bytes} bytes", :green 
        rescue Exception => err_msg
          raise Thor::Error, err_msg
        end
      end

      desc "git GITCOMMAND", "Run git commands inside the :storage_dir directory"
      def git(*commands)
        init()
        begin
          commands = commands.each.collect{|c| c.include?(' ') ? "\"#{c}\"" : c }
          git_command = "git #{commands.join(' ')}"
          inside @config.storage_dir do 
            run git_command
          end
          
        rescue Exception => err_msg
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
          
        rescue Exception => err_msg
          raise Thor::Error, err_msg
        end
      end

      private
      def init()
        begin
          @config = load_config(options[:config_path], force: options[:force])
        rescue Exception => err_msg
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
    end
  end
end