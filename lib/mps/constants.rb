require 'digest/md5'
require 'digest/sha1'


module MPS
  MPS_EXT = "mps"
  MD5_DIGEST = Digest::MD5.new
  SHA1_DIGEST = Digest::SHA1.new
  HOME_DIR = Dir.home
  MPS_CONFIG_FILE = File.join(HOME_DIR, ".mps_config.yml")
  DEFAULT_MPS_DIR = File.join(HOME_DIR, ".mps")
  MPS_NOTE_NAME_REGEXP = Regexp.new("^(.*)\.#{MPS_EXT}")
  MPS_NOTE_NAME_CLIPPER = ->(file_basename){
    MPS_NOTE_NAME_REGEXP=~file_basename
    $~[1]
  }

  RECORD_LOGGER_REGEXP = /\[([0-9]{4}),\s*?([0-9]{1,2}),\s*?([0-9]{1,2})\]->\[(.+?),\s*?(.+?)\]/
  RECORD_DATA_CLIPPER = ->(record_string){
    RECORD_LOGGER_REGEXP=~record_string
    puts("-------> record_string: #{record_string} : It's nil!") if not $~
    $~==nil ? nil : [:year, :month, :day, :note_name, :note_path].zip($~[1..5]).to_h
  }
  RECORD_LOGGER_TWISTER = ->(time, note_name, note_path){
    "[#{time.year}, #{time.month}, #{time.day}]->[#{note_name}, #{note_path}]"
  }

  RECORD_LOGGER = ->(record_file_path, time, note_name, note_path){
    record_file = File.open(record_file_path, "a+")
    record_file.puts(RECORD_LOGGER_TWISTER.call(time, note_name, note_path))
    record_file.close()
  }
  TIME_CLIPPER = ->(time){Time.new(time.year, time.month, time.day)}
end
