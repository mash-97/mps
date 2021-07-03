require_relative("constants")
require_relative("user")

module MPS
  class MPS
    class UserNameExist < StandardError
      def initailze()
        super("Username already exists!")
      end
    end

    class UserNameNotExist < StandardError
      def initailze()
        super("Username doesn't exist!")
      end
    end

    class NotLoggedIn < StandardError
      def initialize()
        super("No user is logged in!")
      end
    end

    attr_accessor :mps_dir
    attr_accessor :users
    attr_accessor :user

    def initialize(mps_dir = DEFAULT_MPS_DIR)
      @mps_dir = mps_dir
      @users = []
      @user = nil
    end

    def signUp(username, plain_password)
      raise(UserNameExist) if userNameExist?(username)
      @users << User.new(username, plain_password)
    end

    def logIn(username, plain_password)
      user = getUser(username)
      raise(UserNameNotExist) if not user
      user.authorize(plain_password) ? @user=user : nil
    end

    def logOut()
      raise(NotLoggedIn) if not @user
      @user.unauthorize()
      @user = nil
    end

    def getUser(username)
      user = @users.select{|u|u.name==username}
      return user.length == 0 ? nil : user.first
    end

    def userNameExist?(username)
      @users.include?(username)
    end

  end
end
