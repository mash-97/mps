# frozen_string_literal: true

module MPS
  module Elements
    class Task
      SIGNATURE_STAMP = "task"
      SIGNATURE_REGEX = /\Atask\z/
      include Element

      attribute :status, type: :string, default: "open", flag: "status", aliases: ["-s"]

      def done? = parsed_args[:status] == "done"
      def open? = !done?
    end
  end
end
