# frozen_string_literal: true

module MPS
  module Element
    PADDING = '  '

    # Parses "work, release, status: done" → { attrs: { status: "done" }, tags: ["work", "release"] }
    # Parts containing ":" become named attrs; bare words become tags.
    def self.split_args(raw)
      return { attrs: {}, tags: [] } if raw.nil? || raw.strip.empty?
      attrs = {}
      tags  = []
      raw.split(",").each do |part|
        part = part.strip
        next if part.empty?
        if part.include?(":")
          k, v = part.split(":", 2).map(&:strip)
          attrs[k.to_sym] = v
        else
          tags << part
        end
      end
      { attrs: attrs, tags: tags }
    end

    attr_accessor :disp_str
    attr_reader   :body_str, :raw_args, :parsed_args

    def initialize(args:, refs:, body_str:)
      @raw_args    = args.to_s
      @refs        = refs
      @body_str    = body_str
      @ref         = refs.map(&:to_s).join(".")
      @parsed_args = self.class.respond_to?(:parse_args) ? self.class.parse_args(@raw_args) : {}
    end

    def tags
      @parsed_args.fetch(:tags, [])
    end

    def display_str(padding_size = @refs.size - 1)
      strs = @body_str.strip.lines.map(&:strip)
      header = strs.first
      res_strs = [(PADDING * padding_size) + header]
      strs[1..].each { |str| res_strs << (PADDING * padding_size) + str }
      res_strs.join("\n")
    end
  end
end
