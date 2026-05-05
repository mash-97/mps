# frozen_string_literal: true

module MPS
  module Elements
    class Note
      SIGNATURE_STAMP = "note"
      SIGNATURE_REGEX = /\Anote\z/
      include Element
      # Notes carry only tags; no typed attributes.
    end
  end
end
