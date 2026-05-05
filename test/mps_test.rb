# frozen_string_literal: true

require "test_helper"

class MPSTest < Minitest::Test
  def test_date_range_file_names
    s_date = MPS.get_date("yesterday")
    e_date = s_date + 3

    check = s_date.dup
    MPS.get_filenames_from_date_range(s_date, e_date).each do |file_name|
      expected_prefix = check.strftime("%Y%m%d")
      assert_match(
        /\A#{expected_prefix}\.\d{10,}\.#{Constants::MPS_EXT}\z/,
        File.basename(file_name)
      )
      check = check.next
    end
  end
end
