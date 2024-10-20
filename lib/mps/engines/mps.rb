# frozen_string_literal: true
# 
require_relative "../utilities"
require_relative "../constants"
require_relative "../config"

require_relative "../elements/mps"
require_relative "../interpolators/time"

require 'strscan'

module MPS
  module Engines
    class EngineError < StandardError;end;
    class MPS
      attr_reader :logger
      attr_reader :element_classes
      attr_reader :interpolator_classes
      def initialize(config)
        @config = config
        @element_classes = ::MPS::Elements.constants.map{|k|eval("::MPS::Elements::#{k}")}.select{|x|x.class==Class}
        @interpolator_classes = ::MPS::Interpolators.constants.map{|k|eval("::MPS::Interpolators::#{k}")}.select{|x|x.class==Class}
        @logger = @config.logger 
      end
      def mps_open(datesign)
        filename = ::MPS.get_filename_from_date(::MPS.get_date(datesign))
        # extend filename for MPS_DIR here.
        ::MPS.open_editor(filename)
      end

      def self.matched_element_class(str, element_classes)
        element_classes.each do |ec|
          return ec if str=~ec::SIGNATURE_REGEXP
        end
      end

      def self.load_elements(mps_file_path, element_classes, interpolator_classes)
        mps_str = File.read(mps_file_path)
        # add elements::mps signature
        mps_str = "@mps[]{"+mps_str+"}"
        str_scanr = StringScanner.new(mps_str)
        reference = nil
      end
    end
  end
end