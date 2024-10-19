# frozen_string_literal: true

require_relative 'test_helper'

class ConfigTest < Minitest::Test
  include Constants
  def setup()
    Config
  end
  def test_default_config()
    FakeFS.with_fresh do 
      FileUtils.mkdir_p(MPS_DIR)
      refute_path_exists MPS_CONFIG_FILE
      assert_raises(MPS::Config::ConfigFileNotFound, "#> should raise configs file not found") do 
        Config.load()
      end

      # first init and then check loaded config
      refute_path_exists MPS_LOG_FILE
      conf = Config.init(force: true)
      assert_equal conf.storage_dir, DEFAULT_CONF_HASH[:storage_dir], "#> storage dir check"
      assert_equal conf.log_file, DEFAULT_CONF_HASH[:log_file], "#> log file check"
      loaded_conf = Config.load()
      assert_equal conf.storage_dir, loaded_conf.storage_dir, "#> storage dir check"
      assert_equal conf.log_file, loaded_conf.log_file, "#> log file check"
    end
  end

  def test_config_load
    FakeFS.with_fresh do 
      FileUtils.mkdir_p(MPS_DIR)
    end
  end

  def test_log 
    FakeFS.with_fresh do 
      FileUtils.mkdir_p MPS_DIR
      refute_path_exists MPS_LOG_FILE
      refute_path_exists MPS_CONFIG_FILE
      assert_raises Config::ConfigFileNotFound, "#> conf file not found" do 
        Config.load()
      end
      conf = Config.init()
      assert_equal conf.storage_dir, DEFAULT_CONF_HASH[:storage_dir]
      assert_equal conf.log_file, DEFAULT_CONF_HASH[:log_file]
      assert_path_exists MPS_LOG_FILE
      assert_path_exists MPS_CONFIG_FILE 
      
      conf.logger.info("info hello world")
      assert_match(/I:[\s\S]*hello world/, File.read(MPS_LOG_FILE))
      conf.logger.debug("debug")
      assert_match(/D:[\s\S]*debug/, File.read(MPS_LOG_FILE))
    end
  end
end
