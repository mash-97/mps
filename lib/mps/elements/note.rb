# frozen string_literal: true

module MPS
  module Elements
    class Note
      SIGNATURE_STAMP = "note"
      SIGNATURE_REGEX = /note/
      include Element
    end
  end
end