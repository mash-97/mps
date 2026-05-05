# frozen_string_literal: true

module MPS
  # Renders an elements hash to a string.
  # Has no dependency on Thor; receives a colorize proc for terminal output.
  #
  # Usage (in CLI):
  #   p = Presenter.new(elements, color_fn: method(:set_color), resolver: resolver)
  #   puts p.render_tree
  class Presenter
    TYPE_COLORS = {
      "task"     => :green,
      "note"     => :cyan,
      "reminder" => :magenta,
      "log"      => :yellow
    }.freeze

    ANSI_CODES = {
      green: "\e[32m", cyan: "\e[36m", magenta: "\e[35m",
      yellow: "\e[33m", white: "\e[37m", reset: "\e[0m"
    }.freeze

    # @param elements_hash [Hash]  ref => element, as returned by Store#parse_date
    # @param color_fn [Proc, nil]  set_color(text, color) — nil disables color
    # @param resolver  [RefResolver, nil]
    # @param with_refs [Boolean]   prefix each line with human ref
    def initialize(elements_hash, color_fn: nil, resolver: nil, with_refs: false)
      @elements  = elements_hash
      @color_fn  = color_fn || method(:_ansi_color)
      @resolver  = resolver
      @with_refs = with_refs
    end

    # Renders elements as an indented tree. @mps containers shown as group headers.
    # Returns the number of non-MPS elements printed, or just the rendered string
    # if called for its side-effect-free return value.
    def render_tree
      sorted = @elements.sort_by { |k, _| k.split(".").map(&:to_i) }
      return ["", 0] if sorted.empty?

      root_segs = sorted.first.first.split(".").size
      lines = []
      shown = 0

      sorted.each do |ref_key, el|
        depth = ref_key.split(".").size - root_segs - 1
        next if depth < 0

        if el.is_a?(::MPS::Elements::MPS)
          prefix = "#{ref_key}."
          any_visible = @elements.any? { |k, v| k.start_with?(prefix) && !v.is_a?(::MPS::Elements::MPS) }
          next unless any_visible
          indent    = "  " * (depth + 1)
          human     = @resolver&.to_human(ref_key) || ref_key
          ref_col   = @with_refs ? "#{_colorize(human.ljust(12), :white)}  " : ""
          lines << "#{indent}#{ref_col}#{_colorize("[@mps]", :white)}"
        else
          indent    = "  " * (depth + 1)
          human     = @resolver&.to_human(ref_key) || ref_key
          ref_col   = @with_refs ? "#{_colorize(human.ljust(12), :white)}  " : ""
          lines << "#{indent}#{ref_col}#{_element_line(el)}"
          shown += 1
        end
      end

      [lines.join("\n"), shown]
    end

    # Renders a single element as a terminal line (no indentation).
    def render_element(el, depth: 0)
      indent = "  " * (depth + 1)
      "#{indent}#{_element_line(el)}"
    end

    # Returns a tag-frequency table as a string.
    # elements_hash should already be filtered (MPS containers excluded).
    def render_tag_table
      counts = Hash.new(0)
      @elements.each_value do |el|
        next if el.is_a?(::MPS::Elements::MPS)
        el.tags.each { |t| counts[t] += 1 }
      end
      return _colorize("(no tags found)", :yellow) if counts.empty?
      counts.sort_by { |_, v| -v }
            .map { |tag, n| "  #{_colorize(tag, :white)} (#{n})" }
            .join("\n")
    end

    private

    def _element_line(el)
      type_name = el.class::SIGNATURE_STAMP
      badge     = _colorize("[#{type_name}]", TYPE_COLORS.fetch(type_name, :white))
      extra     = _element_extra(el)
      body_line = el.body_str.strip.lines.first&.strip
      tags_str  = el.tags.empty? ? "" : " #{_colorize("[#{el.tags.join(', ')}]", :white)}"
      "#{badge} #{extra}#{body_line}#{tags_str}"
    end

    def _element_extra(el)
      case el
      when ::MPS::Elements::Task
        status = el.parsed_args[:status] || "open"
        color  = status == "done" ? :green : :yellow
        "(#{_colorize(status, color)}) "
      when ::MPS::Elements::Log
        dur = el.duration_str
        dur ? "(#{_colorize(dur, :yellow)}) " : ""
      when ::MPS::Elements::Reminder
        at = el.parsed_args[:at]
        at ? "(#{_colorize(at, :magenta)}) " : ""
      else
        ""
      end
    end

    def _colorize(text, color)
      @color_fn.call(text, color)
    end

    # Fallback colorizer using ANSI codes when no Thor color_fn is provided.
    def _ansi_color(text, color)
      code = ANSI_CODES[color]
      return text unless code
      "#{code}#{text}#{ANSI_CODES[:reset]}"
    end
  end
end
