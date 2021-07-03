require_relative("constants")
require_relative("user")

module MPS
  class MPS
    attr_accessor :mps_dir
    attr_accessor :users
    attr_accessor :logged_in_user
    def initialize(mps_dir = DEFAULT_MPS_DIR)
      @mps_dir = mps_dir
      @users = users
    end

    def add_user(username, plain_password)

    end

  end
end
