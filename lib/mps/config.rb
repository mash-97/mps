# frozen_string_literal: true
require 'yaml'
require_relative 'constants'
module MPS
  class Config 
    class LoadError < StandardError;end;
    class FileAreadyExists < StandardError;end;
    attr_accessor :storage_dir
    def initialize()
      @storage_dir = nil
    end

    def self.load(conf_fp=Constants::MPS_CONFIG_FILE)
      if File.exist?(conf_fp)
        conf_hash = YAML.load_file(conf_fp)
        raise LoadError.new("yaml not a hash!") if conf_hash.class!=Hash
        raise LoadError.new("storage_dir key not found!") if conf_hash[:storage_dir]
        return conf_hash
      end
      raise LoadError.new("configs file not found! #{conf_fp}")
    end

    def self.init(conf_fp=Constants::MPS_CONFIG_FILE)
      #
    end
  end
end