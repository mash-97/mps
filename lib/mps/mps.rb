# frozen_string_literal: true

module MPS
  def self.get_date(str)
    result = Chronic.parse(str)
    raise ArgumentError, "Cannot parse date: #{str.inspect}" unless result
    result.to_date
  end

  def self.get_filename_from_date(date)
    Constants::MPS_NEW_FILE_NAME_GEN.call(date)
  end

  def self.get_filenames_from_date_range(s_date, e_date)
    (s_date..e_date).collect { |date| MPS.get_filename_from_date(date) }
  end

  def self.open_editor(text_file)
    init_size = File.exist?(text_file) ? File.size(text_file) : 0
    TTY::Editor.open(text_file, command: "vim")
    curr_size = File.exist?(text_file) ? File.size(text_file) : 0
    curr_size - init_size
  end
end
