# frozen string_literal: true

module MPS
  module Elements
    class Task
      SIGNATURE_STAMP = "task"
      SIGNATURE_REGEX = /task/
      include Element
    end
  end
end