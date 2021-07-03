require 'openssl'
require_relative("mps")

module MPS
  class Cipher < OpenSSL::Cipher::AES
    IV = MD5_DIGEST.digest("MPS:MASH")

    def initialize
      super(128, :CBC)
    end
  end
end
