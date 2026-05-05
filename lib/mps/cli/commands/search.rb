# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "search QUERY", "Full-text search across all .mps files"
  method_option :type,  type: :string, aliases: "-t", desc: "Filter by type"
  method_option :tag,   type: :string, aliases: "-g", desc: "Filter by tag"
  method_option :since, type: :string, aliases: "-S", desc: "Search from this date onward"
  def search(query)
    init
    begin
      since_date = options[:since] ? ::MPS.get_date(options[:since]).to_date : nil
      results    = store.search(
        query,
        type_filter: options[:type]&.downcase,
        tag_filter:  options[:tag],
        since_date:  since_date
      )
      if results.empty?
        say set_color("No results for '#{query}'", :yellow)
        return
      end
      results.each do |r|
        el       = r[:element]
        tags_str = el.tags.empty? ? "" : " #{set_color("[#{el.tags.join(', ')}]", :white)}"
        body_line = el.body_str.strip.lines.first&.strip
        say "#{set_color(r[:date_str], :white)} #{type_badge(el.class::SIGNATURE_STAMP)} " \
            "#{element_extra(el)}#{body_line}#{tags_str}"
      end
      say set_color("(#{results.size} result#{results.size == 1 ? '' : 's'})", :white)
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
