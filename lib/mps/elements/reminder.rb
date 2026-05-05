# frozen_string_literal: true

module MPS
  module Elements
    class Reminder
      SIGNATURE_STAMP = "reminder"
      SIGNATURE_REGEX = /\Areminder\z/
      include Element

      attribute :at, type: :string, default: nil, flag: "at"
    end
  end
end
