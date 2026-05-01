# frozen_string_literal: true

module MPS
  module Elements
    class Task
      SIGNATURE_STAMP = "task"
      SIGNATURE_REGEX = /\Atask\z/
      include Element

      def self.parse_args(raw)
        p = Element.split_args(raw)
        { tags: p[:tags], status: p[:attrs].fetch(:status, "open") }
      end

      def done? = parsed_args[:status] == "done"
      def open? = !done?
    end
  end
end
