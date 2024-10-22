# frozen string_literal: true

module MPS
  module Elements
    class Reminder
      SIGNATURE_STAMP = "reminder"
      SIGNATURE_REGEX = /reminder/
      include Element
    end
  end
end