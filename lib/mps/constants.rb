require 'digest/md5'
require 'digest/sha1'


module MPS
  MD5_DIGEST = Digest::MD5.new
  SHA1_DIGEST = Digest::SHA1.new
  HOME_DIR = Dir.home
  MPS_CONFIG_FILE = File.join(HOME_DIR, ".mps_config")
  DEFAULT_MPS_DIR = File.join(HOME_DIR, ".mps")
end
