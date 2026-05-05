# frozen_string_literal: true

module MPS
  # Encapsulates filter predicates derived from CLI options.
  # Has no dependency on Thor; fully unit-testable.
  #
  # Usage:
  #   q = Query.new(type: "task", status: "open", tag: "work")
  #   filtered_hash = q.apply(elements_hash)
  class Query
    def initialize(opts = {})
      @type_filter = opts[:type]&.downcase
      @tag_filter  = opts[:tag]
      # Collect schema-driven attribute filters from all element classes.
      @attr_filters = _collect_attr_filters(opts)
    end

    # Returns a new hash containing only elements that pass all active filters.
    # @mps container elements are always excluded.
    def apply(elements_hash)
      elements_hash.select { |_, el| !el.is_a?(::MPS::Elements::MPS) && _match?(el) }
    end

    # Applies filters while preserving the full tree structure including @mps
    # containers. Used by the presenter's tree renderer so group headers are
    # correctly suppressed when all their children are filtered out.
    def apply_for_tree(elements_hash)
      elements_hash.select do |ref_key, el|
        if el.is_a?(::MPS::Elements::MPS)
          prefix = "#{ref_key}."
          elements_hash.any? { |k, v| k.start_with?(prefix) && !v.is_a?(::MPS::Elements::MPS) && _match?(v) }
        else
          _match?(el)
        end
      end
    end

    def match?(el)
      _match?(el)
    end

    private

    def _match?(el)
      return false if el.is_a?(::MPS::Engines::Parser::Unknown)
      return false if @type_filter && el.class::SIGNATURE_STAMP != @type_filter
      return false if @tag_filter  && !el.tags.include?(@tag_filter)

      @attr_filters.each do |name, filter_val|
        el_val = el.parsed_args[name]
        return false if el_val.nil? || el_val.to_s != filter_val
      end
      true
    end

    def _collect_attr_filters(opts)
      filters = {}
      ::MPS::Elements.constants
        .map    { |k| ::MPS::Elements.const_get(k) }
        .select { |x| x.class == Class }
        .each do |klass|
          klass.schema.each do |name, defn|
            next unless defn[:flag]
            flag_sym = defn[:flag].tr("-", "_").to_sym
            filters[name] = opts[flag_sym].to_s if opts[flag_sym]
          end
        end
      filters
    end
  end
end
