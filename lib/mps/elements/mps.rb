# frozen_string_literal: true

module MPS
  module Elements
    class MPS
      SIGNATURE_STAMP = "mps"
      SIGNATURE_REGEX = /\Amps\z/
      include Element
      # MPS is a grouping container; carries only tags.
    end
  end
end
