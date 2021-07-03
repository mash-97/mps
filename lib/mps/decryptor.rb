# decrypts texts with the key
require_relative("cipher")

module MPS
  class Decryptor
    def initialize(key)
      @cipher = MPS::Cipher.new
      @cipher.decrypt
      @cipher.key = key
      @cipher.iv = MPS::Cipher::IV
    end

    def decrypt(content)

      return   @cipher.update(content)+@cipher.final
    end
  end
end
