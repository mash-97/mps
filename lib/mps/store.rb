# frozen_string_literal: true

module MPS
  class Store
    def initialize(storage_dir)
      @storage_dir     = storage_dir
      @element_classes = Elements.constants
        .map    { |k| Elements.const_get(k) }
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
      Engines::Parser.parse_mps_file_to_elements_hash(path, @element_classes)
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
    # +since_date+ is a Date; +type_filter+ and +tag_filter+ are strings.
    def search(query, type_filter: nil, tag_filter: nil, since_date: nil)
      files = since_date ? files_since(since_date) : all_files
      files.flat_map do |file|
        date_str = File.basename(file).slice(0, 8)
        Engines::Parser.parse_mps_file_to_elements_hash(file, @element_classes)
          .values
          .reject { |e| e.is_a?(Elements::MPS) }
          .select { |e| type_filter.nil? || e.class::SIGNATURE_STAMP == type_filter }
          .select { |e| tag_filter.nil?  || e.tags.include?(tag_filter) }
          .select { |e| query.nil?       || e.body_str.downcase.include?(query.downcase) }
          .map    { |e| { element: e, file: file, date_str: date_str } }
      end
    end
  end
end
