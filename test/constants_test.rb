# frozen_string_literal: true
require 'fakefs/safe'
require_relative 'test_helper'


class ConstantsTest < Minitest::Test
  def setup()
    @valid_mps_fns = ["20240102.mps", "19990103.mps", "18891333.mps"]
    @invalid_mps_fns = ["111111111.mps"]
  end
  def test_mps_filename_regexp()
    @valid_mps_fns.each do |vmf|
      assert MPS::Constants::MPS_FILE_NAME_REGEXP=~vmf
    end
    @invalid_mps_fns.each do |ivmf|
      refute MPS::Constants::MPS_FILE_NAME_REGEXP=~ivmf
    end
  end

  def test_date_clipper()
    @valid_mps_fns.each do |vmf|
      t = {
        :year => vmf[..3],
        :month => vmf[4..5],
        :day => vmf[6..7]
      }
      assert_equal MPS::Constants::MPS_FILE_NAME_DATE_CLIPPER.call(vmf), t, "Date clipper not matched for: #{vmf.to_s}"
    end
  end

  def test_mps_dir_structure_existance()
    FakeFS.with_fresh do
      puts("#> dir.home: #{Dir.home}") 
      FileUtils.mkdir_p(MPS::Constants::MPS_STORAGE_DIR)
      FileUtils.touch(MPS::Constants::MPS_CONFIG_FILE)
      assert Dir.exist?(MPS::Constants::MPS_DIR)
      assert File.exist?(MPS::Constants::MPS_CONFIG_FILE)
      assert Dir.exist?(MPS::Constants::MPS_STORAGE_DIR)
    end
  end
end
