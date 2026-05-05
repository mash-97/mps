# frozen_string_literal: true

module MPS
  # Translates between epoch ref-paths (e.g. "20260428.2.1") and
  # human-readable refs (e.g. "note-1.1").
  #
  # Human ref format:
  #   Top-level non-MPS:  {type}-{n}         where n counts per type across top-level
  #   First-level nested: {parent_human}.{m}  where m is the child's sequential index
  #   Deeper nesting:     same pattern extended (type-1.2.1, etc.)
  #   @mps containers:    mps-{n}
  class RefResolver
    def initialize(elements_hash)
      @epoch_to_human = {}
      @human_to_epoch = {}
      _build_maps(elements_hash)
    end

    # Returns the human ref for +epoch_ref+, or nil if not mapped.
    def to_human(epoch_ref)
      @epoch_to_human[epoch_ref]
    end

    # Returns the epoch ref for +human_ref+, or nil if not mapped.
    def to_epoch(human_ref)
      @human_to_epoch[human_ref]
    end

    # Resolves either form. Human refs are translated to epoch; epoch refs
    # are returned as-is (validated to exist in the mapping).
    def resolve(ref_str)
      return @human_to_epoch[ref_str] if @human_to_epoch.key?(ref_str)
      return ref_str if @epoch_to_human.key?(ref_str)
      nil
    end

    # Returns all mapped epoch refs sorted by document order.
    def all_epoch_refs
      @epoch_to_human.keys
    end

    private

    def _build_maps(elements_hash)
      return if elements_hash.empty?

      sorted = elements_hash.sort_by { |k, _| k.split(".").map(&:to_i) }
      root_ref   = sorted.first.first
      root_depth = root_ref.split(".").size  # always 1 (epoch only)

      type_counters = Hash.new(0)

      sorted.each do |epoch_ref, el|
        depth = epoch_ref.split(".").size - root_depth  # 0=root, 1=top-level, 2+=nested

        next if depth <= 0  # skip synthetic root wrapper

        if depth == 1
          next if el.is_a?(Engines::Parser::Unknown)
          type_name = el.class::SIGNATURE_STAMP
          type_counters[type_name] += 1
          human = "#{type_name}-#{type_counters[type_name]}"
        else
          parts        = epoch_ref.split(".")
          parent_epoch = parts[0..-2].join(".")
          child_idx    = parts.last
          parent_human = @epoch_to_human[parent_epoch]
          next unless parent_human
          human = "#{parent_human}.#{child_idx}"
        end

        @epoch_to_human[epoch_ref] = human
        @human_to_epoch[human]     = epoch_ref
      end
    end
  end
end
