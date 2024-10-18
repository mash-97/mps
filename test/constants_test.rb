# frozen_string_literal: true

require_relative 'test_helper'


class ConstantsTest < Minitest::Test
  def setup()
    @valid_mps_fns = ["20240102.mps", "19990103.mps", "18891333.mps"]
    @invalid_mps_fns = ["111111111.mps"]
  end
  def test_mps_filename()
    @valid_mps_fns.each do |vmf|
      assert MPS::Constants::MPS_FILE_NAME_REGEXP=~vmf
    end
    @invalid_mps_fns.each do |ivmf|
      refute MPS::Constants::MPS_FILE_NAME_REGEXP=~ivmf
    end
  end
end
