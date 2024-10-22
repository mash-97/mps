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
  def self.constantsTree(constant=nil)
    return nil if !constant
    return nil if !(constant.class==Module or constant.class==Class)
    puts("#> 1, #{constant}")
    hash = {}
    constant.constants.each do |const|
      x = eval("#{constant}::#{const}")
      if [Module, Class].include?(x.class) and x.constants == constant.constants
        hash[const] = nil 
        next
      end
      hash[const] = self.constantsTree(x)
    end
    return hash 
  end

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

