# frozen_string_literal: true

module MPS
  module Elements
    class Log
      SIGNATURE_STAMP = "log"
      SIGNATURE_REGEX = /\Alog\z/
      include Element

      def self.parse_args(raw)
        p = Element.split_args(raw)
        { tags: p[:tags], start: p[:attrs][:start], end: p[:attrs][:end] }
      end

      def duration_minutes
        s = parsed_args[:start]
        e = parsed_args[:end]
        return nil unless s && e
        sh, sm = s.split(":").map(&:to_i)
        eh, em = e.split(":").map(&:to_i)
        (eh * 60 + em) - (sh * 60 + sm)
      end

      def duration_str
        mins = duration_minutes
        return nil unless mins && mins > 0
        h, m = mins.divmod(60)
        m > 0 ? "#{h}h#{m}m" : "#{h}h"
      end
    end
  end
end
