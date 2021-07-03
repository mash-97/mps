require_relative("constants")

module MPS
  class User
    attr_accessor :name
    attr_accessor :password_md5
    attr_accessor :password_sha1
    attr_accessor :mps_storage_dir
    attr_accessor :mps_record_file

    def initialize(name, plain_password)
      @name = name
      @password_md5 = MD5_DIGEST.digest(plain_password)
      @password_sha1 = SHA1_DIGEST.digest(plain_password)
      @mps_storage_dir = User.get_default_user_mps_storage_dir(@name)
      @mps_record_file = User.get_user_mps_record_file(@mps_storage_dir)
    end

    def update_mps_storage_dir(mps_storage_dir)
      @mps_storage_dir = mps_storage_dir
      @mps_record_file = User.get_user_mps_record_file(@mps_storage_dir)
    end

    def self.get_default_user_mps_storage_dir(username)
      File.join(DEFAULT_MPS_DIR, username)
    end

    def self.get_user_mps_record_file(mps_storage_dir)
      File.join(mps_storage_dir, ".mps_records.txt")
    end
  end
end
