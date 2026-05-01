# frozen_string_literal: true

module MPS
  module Elements
    class Note
      SIGNATURE_STAMP = "note"
      SIGNATURE_REGEX = /\Anote\z/
      include Element

      def self.parse_args(raw)
        { tags: Element.split_args(raw)[:tags] }
      end
    end
  end
end
