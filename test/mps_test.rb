# frozen_string_literal: true

require "test_helper"

class MPSTest < Minitest::Test

  def setup()
  
  end
  
  def test_date_range_file_names
    s_date = MPS.get_date('yesterday')
    e_date = MPS.get_date('999977 days after today')

    MPS.get_filenames_from_date_range(s_date, e_date).each do 
      |file_name|
      assert_equal file_name, s_date.strftime("%Y%m%d")+"."+Constants::MPS_EXT
      s_date = s_date.next
    end
  end
end
