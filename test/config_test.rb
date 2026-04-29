# frozen_string_literal: true

require_relative 'test_helper'

class ConfigTest < Minitest::Test
  include Constants

  def test_default_config
    FakeFS.with_fresh do
      FileUtils.mkdir_p(MPS_DIR)
      refute File.exist?(MPS_CONFIG_FILE)
      assert_raises(Config::ConfigFileNotFound) do
        Config.load_conf_hash(MPS_CONFIG_FILE)
      end
      Config.init(MPS_CONFIG_FILE)
      assert File.exist?(MPS_CONFIG_FILE)
      conf_hash = Config.load_conf_hash(MPS_CONFIG_FILE)
      assert_equal DEFAULT_CONF_HASH[:storage_dir], conf_hash[:storage_dir]
      assert_equal DEFAULT_CONF_HASH[:log_file],    conf_hash[:log_file]
      assert_equal DEFAULT_CONF_HASH[:mps_dir],     conf_hash[:mps_dir]
    end
  end

  def test_config_load
    FakeFS.with_fresh do
      FileUtils.mkdir_p(MPS_DIR)
      FileUtils.mkdir_p(MPS_STORAGE_DIR)
      Config.init(MPS_CONFIG_FILE)
      FileUtils.touch(DEFAULT_CONF_HASH[:log_file])
      conf_hash = Config.load_conf_hash(MPS_CONFIG_FILE)
      config    = Config.new(**conf_hash)
      assert_equal DEFAULT_CONF_HASH[:storage_dir], config.storage_dir
      assert_equal DEFAULT_CONF_HASH[:log_file],    config.log_file
      assert_equal "origin",  config.git_remote
      assert_equal "master",  config.git_branch
    end
  end

  def test_log
    FakeFS.with_fresh do
      FileUtils.mkdir_p(MPS_DIR)
      FileUtils.mkdir_p(MPS_STORAGE_DIR)
      Config.init(MPS_CONFIG_FILE)
      FileUtils.touch(DEFAULT_CONF_HASH[:log_file])
      config = Config.new(**Config.load_conf_hash(MPS_CONFIG_FILE))
      config.logger.info("hello world")
      config.logger.close
      log_content = File.read(DEFAULT_CONF_HASH[:log_file])
      assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] I: hello world/, log_content)
    end
  end

  def test_load_conf_hash_raises_on_missing_key
    FakeFS.with_fresh do
      FileUtils.mkdir_p(MPS_DIR)
      partial_yaml = MPS_CONFIG_FILE
      File.open(partial_yaml, "w") { |f| f.write(YAML.dump({ storage_dir: "/tmp/storage" })) }
      assert_raises(Config::LoadError) do
        Config.load_conf_hash(partial_yaml)
      end
    end
  end
end
