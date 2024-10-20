# frozen_string_literal: true

require 'thor'
require_relative '../mps/mps.rb'

module MPS
  module CLI 
    class MPS < Thor
      default_task :open
      
      desc "open DATESIGN", "Open mps file in editor, usually in Vim"
      def open(datesign="today")
        ::MPS::Engines::MPS.mps_open(datesign)
      end
    end
  end
end