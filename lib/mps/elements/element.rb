# frozen_string_literal: true


module MPS
  module Elements
    module Element 
      PADDING = '  '
      attr_accessor :disp_str
      attr_reader :body_str
      attr_reader :refs
      attr_reader :ref 
      attr_reader :args 
      attr_reader :tags
      def initialize(args: [], refs: nil, body_str: nil)
        @args = args
        @refs = refs
        @body_str = body_str
        @ref = @refs.map(&:to_s).join(".")
        @disp_str = nil
        @tags = []
      end
      def self.display_str(body_str, padding_size=0)
        strs = body_str.strip().lines.map(&:strip)
        header = strs.first ? strs.first : ""
        res_strs = [(PADDING*padding_size)+header]
        if strs[1..] != nil then 
          strs[1..].each do |str| res_strs << (PADDING*padding_size)+str end  
        end
        return res_strs.join("\n")
        # return "it's a hidden element with ref ##{@ref} for display test"
      end

    end
  end
end