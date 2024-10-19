# frozen_string_literal: true

require_relative 'test_helper'

class ConfigTest < Minitest::Test
  def setup()
    Config
  end
  def test_default_config()
    FakeFS.with_fresh do 
      FileUtils.mkdir_p(Constants::MPS_DIR)
      refute_path_exists Constants::MPS_CONFIG_FILE
      assert_raises(MPS::Config::ConfigFileNotFound, "#> should raise configs file not found") do 
        Config.load()
      end

      # first init and then check loaded config
      refute_path_exists Constants::MPS_LOG_FILE
      conf = Config.init(force: true)
      assert_equal conf.storage_dir, Constants::DEFAULT_CONF_HASH[:storage_dir], "#> storage dir check"
      assert_equal conf.log_file, Constants::DEFAULT_CONF_HASH[:log_file], "#> log file check"
      loaded_conf = Config.load()
      assert_equal conf.storage_dir, loaded_conf.storage_dir, "#> storage dir check"
      assert_equal conf.log_file, loaded_conf.log_file, "#> log file check"
    end
  end

  def test_config_load
    FakeFS.with_fresh do 
      FileUtils.mkdir_p(Constants::MPS_DIR)
    end
  end
end
