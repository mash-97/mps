# frozen_string_literal: true

module MPS
  module Element
    # Called when Element is included in a class. Extends the class with
    # ClassMethods, enabling the `attribute` schema DSL.
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Declare a typed attribute for this element class.
      #
      # @param name [Symbol]  parsed_args key
      # @param type [Symbol]  :string, :time, :integer (for future coercion)
      # @param default        value when the attribute is absent from args
      # @param flag [String]  CLI flag name (without --); nil = not filterable
      # @param aliases [Array<String>] short CLI aliases for this flag
      def attribute(name, type: :string, default: nil, flag: nil, aliases: [])
        _schema[name] = { type: type, default: default, flag: flag, aliases: Array(aliases) }
      end

      # Internal mutable schema hash.
      def _schema
        @_schema ||= {}
      end

      # Frozen public view of the schema.
      def schema
        _schema.dup.freeze
      end

      # Schema-driven parse_args. Subclasses do NOT need to override this.
      # Any key: value pair in raw whose key matches a declared attribute name
      # is extracted; remaining bare words become tags.
      def parse_args(raw)
        split = ::MPS::Element.split_args(raw)
        result = { tags: split[:tags] }
        _schema.each do |name, defn|
          result[name] = split[:attrs].fetch(name, defn[:default])
        end
        result
      end
    end

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

    attr_reader :body_str, :raw_args, :parsed_args

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
  end
end
