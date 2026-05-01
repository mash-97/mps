# frozen_string_literal: true

module MPS
  module Elements
    class MPS
      SIGNATURE_STAMP = "mps"
      SIGNATURE_REGEX = /\Amps\z/
      include Element

      def self.parse_args(raw)
        { tags: Element.split_args(raw)[:tags] }
      end
    end
  end
end
