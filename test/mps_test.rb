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

  def test_get_date_raises_on_unparseable_string
    assert_raises(ArgumentError) { MPS.get_date("--all") }
    assert_raises(ArgumentError) { MPS.get_date("not-a-date-at-all-xyz") }
  end

  def test_get_date_returns_date_for_known_expressions
    assert_instance_of Date, MPS.get_date("today")
    assert_instance_of Date, MPS.get_date("yesterday")
    assert_instance_of Date, MPS.get_date("2026-01-01")
  end
end
