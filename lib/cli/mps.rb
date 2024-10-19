# frozen_string_literal: true

require 'thor'
require_relative '../mps/mps.rb'

module MPS
  module CLI 
    class MPS < Thor
      desc "open DATESIGN", "Open mps file in editor, usually in Vim"
      def open(datesign)
        filename = ::MPS.get_filename_from_date(::MPS.get_date(datesign))
        # extend filename for MPS_DIR here.
        ::MPS.open_editor(filename)
      end
    end
  end
end