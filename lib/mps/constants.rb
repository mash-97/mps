# frozen_string_literal: true
module MPS
  module Constants
    # mps file extention
    MPS_EXT = "mps"

    # user home directory
    HOME_DIR = Dir.home

    # default mps directory where all mps related files will be stored,
    # including mps storage directory, config, log files etc.
    MPS_DIR = File.join(HOME_DIR, ".mps")

    # mps config default file path
    MPS_CONFIG_FILE = File.join(HOME_DIR, ".mps_config.yaml")

    # default mps storage directory, usually where the mps files 
    # will be stored. but should configurable to any path through 
    # config.
    MPS_STORAGE_DIR = File.join(MPS_DIR, "mps")

    # mps file name structure
    MPS_FILE_NAME_REGEXP = Regexp.new("^((\\d{4})(\\d{2})(\\d{2}))\\.#{MPS_EXT}$")

    # clip the mps filename except the extention, usually datestamp
    MPS_FILE_NAME_CLIPPER = ->(file_basename){
      MPS_FILE_NAME_REGEXP=~file_basename
      $~[1]
    }

    # clip datestamp with hash accessibility from the mps filename
    MPS_FILE_NAME_DATE_CLIPPER = ->(file_basename){
      MPS_FILE_NAME_REGEXP=~file_basename
      {
        year: $~[2],
        month: $~[3],
        day: $~[4]
      }
    }
  end
end
