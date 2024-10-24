# frozen_string_literal: true
# 

def ir(rltv_rb_fp)
  clf = caller_locations.first
  f, l = clf.path, clf.lineno
  rltv_rb_fp = File.expand_path(rltv_rb_fp, File.dirname(f))
  r = require_relative(rltv_rb_fp)
  puts("#{f} at #{l} for #{rltv_rb_fp}  #=> #{r}") if ENV["MPS_DEBUG"]=="true"
end
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
    init_size = 0
    init_size = File.size(text_file) if File.exist?(text_file)
    TTY::Editor.open(text_file, command: "vim")
    curr_size = 0
    curr_size = File.size(text_file) if File.exist?(text_file)
    return curr_size-init_size
  end
end

