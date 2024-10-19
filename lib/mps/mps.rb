# frozen_string_literal: true

require("chronic")
require("tty-editor")
require_relative("constants")
require_relative("config")
module MPS
  def self.get_date(str)
    return Chronic.parse(str).to_date
  end
  def self.get_filename_from_date(date)
    "#{date.strftime('%Y%m%d')}.#{Constants::MPS_EXT}"
  end
  def self.get_filenames_from_date_range(s_date, e_date)
    (s_date..e_date).collect do |date|
      MPS.get_filename_from_date(date)
    end
  end
  def self.open_editor(text_file)
    TTY::Editor.open(text_file, command: "vim")
  end
end
