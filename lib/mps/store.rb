# frozen_string_literal: true

module MPS
  class Store
    def initialize(storage_dir)
      @storage_dir        = storage_dir
      @element_classes    = Elements.constants
        .map    { |k| Elements.const_get(k) }
        .select { |x| x.class == Class }
      @interpolator_classes = Interpolators.constants
        .map    { |k| Interpolators.const_get(k) }
        .select { |x| x.class == Class }
    end

    # First .mps file found for +date+, or nil.
    def find_file(date)
      find_files(date).first
    end

    # All .mps files matching +date+ (handles multiple files per day).
    def find_files(date)
      date_str = date.strftime("%Y%m%d")
      Dir[File.join(@storage_dir, "#{date_str}*.#{Constants::MPS_EXT}")]
        .select { |f| File.basename(f) =~ Constants::MPS_FILE_NAME_REGEXP }
        .sort
    end

    # Existing file for +date+, or a generated new path (file not yet created).
    def find_or_create_path(date)
      find_file(date) || File.join(@storage_dir, Constants::MPS_NEW_FILE_NAME_GEN.call(date))
    end

    # Parsed elements hash for +date+. Returns {} when no file exists.
    def parse_date(date)
      path = find_file(date)
      return {} unless path
      Engines::Parser.parse_mps_file_to_elements_hash(
        path, @element_classes, interpolator_classes: @interpolator_classes
      )
    end

    # Returns a RefResolver built from the parsed elements for +date+.
    def resolver_for(date)
      RefResolver.new(parse_date(date))
    end

    # Appends a new element to today's (or +date+'s) file. Returns the file path.
    def append(type:, body:, tags: [], attrs: {}, date: Date.today)
      args_parts = attrs.map { |k, v| "#{k}: #{v}" } + Array(tags)
      args_str   = args_parts.join(", ")
      path       = find_or_create_path(date)
      File.open(path, "a") { |f| f.write("\n@#{type}[#{args_str}]{\n  #{body}\n}\n") }
      path
    end

    # All .mps files in storage, sorted by filename (chronological).
    def all_files
      Dir[File.join(@storage_dir, "*.#{Constants::MPS_EXT}")]
        .select { |f| File.basename(f) =~ Constants::MPS_FILE_NAME_REGEXP }
        .sort
    end

    # Files whose date-stamp is >= +since_date+.
    def files_since(since_date)
      since_str = since_date.strftime("%Y%m%d")
      all_files.select { |f| File.basename(f).slice(0, 8) >= since_str }
    end

    # Full-text search across files. Returns [{element:, file:, date_str:}].
    def search(query, type_filter: nil, tag_filter: nil, since_date: nil)
      files = since_date ? files_since(since_date) : all_files
      files.flat_map do |file|
        date_str = File.basename(file).slice(0, 8)
        Engines::Parser.parse_mps_file_to_elements_hash(
          file, @element_classes, interpolator_classes: @interpolator_classes
        )
          .values
          .reject { |e| e.is_a?(Elements::MPS) || e.is_a?(Engines::Parser::Unknown) }
          .select { |e| type_filter.nil? || e.class::SIGNATURE_STAMP == type_filter }
          .select { |e| tag_filter.nil?  || e.tags.include?(tag_filter) }
          .select { |e| query.nil?       || e.body_str.downcase.include?(query.downcase) }
          .map    { |e| { element: e, file: file, date_str: date_str } }
      end
    end

    # Rewrites an element's args bracket in-place and saves atomically.
    #
    # +ref_str+ may be an epoch ref ("20260428.1") or a human ref ("task-1").
    # Human refs are resolved against +date+ (defaults to today).
    # +new_attrs+ is a hash of attribute_name => new_value (symbol keys).
    # Returns true on success, false if element not found or file unchanged.
    def rewrite_element(ref_str, new_attrs, date: Date.today)
      epoch_ref, path = _resolve_ref_to_path(ref_str, date)
      return false unless epoch_ref && path

      elements = Engines::Parser.parse_mps_file_to_elements_hash(path, @element_classes)
      el = elements[epoch_ref]
      return false unless el
      return false if el.is_a?(Engines::Parser::Unknown)

      _rewrite_element_in_file(path, el, epoch_ref, elements, new_attrs)
    end

    private

    # Returns [epoch_ref, file_path] for the given ref_str, or [nil, nil].
    def _resolve_ref_to_path(ref_str, date)
      if ref_str =~ /\A\d{8}\.\d/
        # Epoch ref — date is encoded in the prefix (YYYYMMDD)
        date_str = ref_str[0, 8]
        begin
          d = Date.strptime(date_str, "%Y%m%d")
        rescue ArgumentError
          return [nil, nil]
        end
        path = find_file(d)
        return [nil, nil] unless path
        [ref_str, path]
      else
        # Human ref — resolve using the given date
        path = find_file(date)
        return [nil, nil] unless path
        elements = Engines::Parser.parse_mps_file_to_elements_hash(path, @element_classes)
        resolver = RefResolver.new(elements)
        epoch_ref = resolver.to_epoch(ref_str)
        return [nil, nil] unless epoch_ref
        [epoch_ref, path]
      end
    end

    # Rewrites the @type[args]{ opener for a specific element in +path+.
    #
    # When two elements share identical raw_args (e.g. both `@task[work, status: open]`),
    # a naive sub() would always patch the first occurrence regardless of which element
    # was targeted. To avoid this, we sort all elements by their numeric ref-path parts
    # (which mirrors the order openers appear in the file) and count how many elements
    # with the same (type, raw_args) precede our target. We then replace exactly that
    # occurrence index in the file text.
    def _rewrite_element_in_file(path, el, epoch_ref, elements, new_attrs)
      content = File.read(path)
      type    = el.class::SIGNATURE_STAMP
      raw     = el.raw_args.to_s

      existing_tags  = el.tags.dup
      merged         = el.parsed_args.reject { |k, _| k == :tags }.merge(new_attrs)
      new_attr_parts = merged.reject { |_, v| v.nil? }.map { |k, v| "#{k}: #{v}" }
      new_args       = (new_attr_parts + existing_tags).join(", ")

      if raw.empty?
        old_pat  = /@#{Regexp.escape(type)}(?:\[\])?\s*\{/
        new_open = "@#{type}[#{new_args}]{"
      else
        old_pat  = /@#{Regexp.escape(type)}\[#{Regexp.escape(raw)}\]\s*\{/
        new_open = "@#{type}[#{new_args}]{"
      end

      # Count how many elements with the same (type, raw_args) appear before our
      # target in document order (sorted by numeric ref-path parts).
      sorted_refs = elements.keys.sort_by { |k| k.split(".").map(&:to_i) }
      occurrence = 0
      sorted_refs.each do |key|
        break if key == epoch_ref
        next unless key.include?(".")
        other = elements[key]
        next if other.is_a?(Engines::Parser::Unknown)
        if other.class::SIGNATURE_STAMP == type && other.raw_args == raw
          occurrence += 1
        end
      end

      # Find all match positions and replace only the (occurrence)-th one (0-indexed).
      positions = []
      pos = 0
      while (m = old_pat.match(content, pos))
        positions << m.begin(0)
        pos = m.end(0)
      end

      return false if occurrence >= positions.size

      m = old_pat.match(content, positions[occurrence])
      return false unless m

      new_content = content[0, m.begin(0)] + new_open + content[m.end(0)..]
      return false if new_content == content

      tmp = "#{path}.tmp.#{Process.pid}"
      begin
        File.write(tmp, new_content)
        File.rename(tmp, path)
        true
      rescue StandardError
        File.delete(tmp) if File.exist?(tmp)
        false
      end
    end
  end
end
