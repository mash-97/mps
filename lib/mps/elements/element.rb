# frozen_string_literal: true


module MPS
  module Element 
    PADDING = '  '
    attr_accessor :disp_str
    def initialize(args: [], refs: nil, body_str: nil)
      @args = args
      @refs = refs
      @body_str = body_str
      @ref = @refs.map(&:to_s).join(".")
    end
    def display_str(padding_size=@refs.size-1)
      strs = @body_str.strip().lines.map(&:strip)
      header = strs.first 
      res_strs = [(PADDING*padding_size)+header]
      strs[1..].each do |str| res_strs << (PADDING*padding_size)+str end
      return res_strs.join("\n")
    end

  end
end