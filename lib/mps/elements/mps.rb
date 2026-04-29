# frozen_string_literal: true

module MPS
  module Elements
    class MPS
      SIGNATURE_STAMP = "mps"
      SIGNATURE_REGEX = /mps/
      include Element
    end
  end
end