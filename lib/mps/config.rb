# frozen_string_literal: true
require 'yaml'
require 'logger'
require_relative 'constants'

module MPS
  # Configuration class
  #
  # To use an instance of the class to contain
  # necessary configuration data and tasks
  class Config 
    class LoadError < StandardError;end;
    class ConfigFileAlreadyExist < StandardError;end;
    class ConfigFileNotFound < StandardError;end;

    attr_reader :storage_dir
    attr_reader :logger
    attr_reader :log_file
    def initialize(**conf_hash)
      @storage_dir = conf_hash[:storage_dir]
      @log_file = conf_hash[:log_file]
      @logger = Logger.new(File.open(@log_file, "a+"))
      @logger.formatter = proc do |sev, time, pn, msg|
        time = time.strftime("[%Y-%m-%d %H:%M:%S]")
        sev = {"INFO"=> "I", "WARN"=>"W", "ERROR"=>"E", "FATAL"=> "F", "DEBUG"=>"D"}[sev]
        "#{time} #{sev}: #{msg}"
      end
    end

    # Loads a yaml configuration file
    #
    # @param conf_fp [String] file path to the yaml config file
    # @note This is method checks for the loaded yaml data, if it doesn't contain necessary data conforming to the contextual configuration data, should raise appropriate StandardError.
    # @return [Config] should return a Config instance
    def self.load(conf_fp=Constants::MPS_CONFIG_FILE)
      if File.exist?(conf_fp)
        conf_hash = YAML.load_file(conf_fp)
        raise LoadError.new("yaml not a hash") if conf_hash.class!=Hash
        raise LoadError.new("storage_dir key requires") if not conf_hash[:storage_dir]
        raise LoadError.new("log_file key requires") if not conf_hash[:log_file]
        return Config.new(**conf_hash)
      end
      raise ConfigFileNotFound.new("configs file not found")
    end

    # initialize a yaml config file for mps
    # if the file already exists skips
    # 
    # @param conf_fp [String] file path to the yaml config file
    # @param force [Boolean] forces even file exists
    # @return [Conf] Conf object
    def self.init(**hash)
      conf_fp=hash[:conf_fp] || Constants::MPS_CONFIG_FILE
      force=hash[:force] || false
      if File.exist?(conf_fp)
        raise ConfigFileAlreadyExist("file already exist") if not force  
      end
      YAML.dump(Constants::DEFAULT_CONF_HASH, File.open(conf_fp, "w+"))
      return Config.new(**Constants::DEFAULT_CONF_HASH)
    end
  end
end