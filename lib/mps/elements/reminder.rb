# frozen_string_literal: true

module MPS
  module Elements
    class Reminder
      SIGNATURE_STAMP = "reminder"
      SIGNATURE_REGEX = /\Areminder\z/
      include Element

      def self.parse_args(raw)
        p = Element.split_args(raw)
        { tags: p[:tags], at: p[:attrs][:at] }
      end
    end
  end
end
