# encripts texts with the key
require_relative("cipher")

module MPS
  class Encryptor
    def initialize(key)
      @cipher = MPS::Cipher.new
      @cipher.encrypt
      @cipher.key = key
      @cipher.iv = MPS::Cipher::IV
    end

    def encrypt(content)

      return @cipher.update(content) + @cipher.final
    end
  end
end


if $0==__FILE__ then
  require_relative("decryptor")
  include MPS

  encryptor = Encryptor.new(MD5_DIGEST.digest("mash"))
  decryptor = Decryptor.new(MD5_DIGEST.digest("mash"))
  
  content = "This is mash!\nOn EnDec"

  encrypted = encryptor.encrypt(content)
  decrypted = decryptor.decrypt(encrypted)

  puts("Encrypted: #{encrypted}")
  puts("Decrypted: #{decrypted}")
end
