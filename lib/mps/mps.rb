# frozen string_literal: true

require("chronic")
require_relative("constants")
require_relative("config")
module MPS
  def self.get_date(str)
    return Chronic.parse(str).to_date
  end
  def self.get_filenames_from_date_range(s_date, e_date)
    (s_date..e_date).collect do |date|
      "#{date.strftime('%Y%m%d')}.#{Constants::MPS_EXT}"
    end
  end
end
