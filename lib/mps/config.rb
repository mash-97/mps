# frozen_string_literal: true

module MPS
  # Configuration class
  #
  # To use an instance of the class to contain
  # necessary configuration data and tasks
  class Config 
    class LoadError < StandardError;end;
    class ConfigFileAlreadyExist < StandardError;end;
    class ConfigFileNotFound < StandardError;end;
    class MPSDirectoryNotFound < StandardError;end;
    class MPSStorageDirectoryNotFound < StandardError;end;

    attr_reader :storage_dir
    attr_reader :logger
    attr_reader :log_file
    def initialize(**conf_hash)
      @mps_dir = conf_hash[:mps_dir]
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
    # @return [Hash] should return a Config hash
    
    def self.load_conf_hash(conf_fp)
      if File.exist?(conf_fp)
        conf_hash = YAML.load_file(conf_fp)
        raise LoadError.new("yaml not a hash") if conf_hash.class!=Hash
        raise LoadError.new("storage_dir key requires") if not conf_hash[:storage_dir]
        raise LoadError.new("log_file key requires") if not conf_hash[:log_file]
        raise LoadError.new("mps_dir key requires") if not conf_hash[:mps_dir]
        return conf_hash
      end
      raise ConfigFileNotFound.new("configs file not found")
    end

    # initialize a yaml config file for mps
    # if the file already exists skips
    # 
    # @param conf_fp [String] file path to the yaml config file
    # @param force [Boolean] forces even file exists
    # @return [Conf] Conf object
    def self.init(conf_fp)
      File.open(conf_fp, "w+") do |f|
        YAML.dump(Constants::DEFAULT_CONF_HASH, f)
      end
    end
  end
end