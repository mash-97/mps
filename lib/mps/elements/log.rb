# frozen string_literal: true

module MPS
  module Elements
    class Log
      SIGNATURE_STAMP = "log"
      SIGNATURE_REGEX = /log/
      include Element
    end
  end
end