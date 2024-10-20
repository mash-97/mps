# frozen_string_literal: true
# 

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
