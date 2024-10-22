# frozen_string_literal: true
module MPS
  module Interpolators
    class Time
      SIGNATURE_REGEX = /:time/
      def get_str(**ref)
        Chronic.parse(ref[:args].first).strftime("Date: %Y-%m-%d, Time: %H:%M")
      end
    end
  end
end