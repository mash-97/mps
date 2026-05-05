# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "export [DATESIGN]", "Export elements to JSON or CSV (writes to stdout)"
  method_option :format, type: :string, default: "json", aliases: "-f",
                         desc: "Output format: json, csv"
  method_option :type,   type: :string, aliases: "-t", desc: "Filter by type"
  method_option :since,  type: :string, aliases: "-S",
                         desc: "Export from SINCE up to DATESIGN"
  def export(datesign = "today")
    init
    begin
      date  = ::MPS.get_date(datesign)
      dates = options[:since] ? date_range(options[:since], date) : [date.to_date]
      fmt   = options[:format].downcase

      unless %w[json csv].include?(fmt)
        raise Thor::Error, "Unknown format '#{fmt}'. Use: json, csv"
      end

      records = []
      dates.each do |d|
        store.parse_date(d).each do |ref, el|
          next if el.is_a?(::MPS::Elements::MPS) || el.is_a?(::MPS::Engines::Parser::Unknown)
          next if options[:type] && el.class::SIGNATURE_STAMP != options[:type].downcase
          extra = el.parsed_args.reject { |k, _| k == :tags }
          records << {
            date: d.strftime("%Y-%m-%d"),
            ref:  ref,
            type: el.class::SIGNATURE_STAMP,
            tags: el.tags.join(","),
            body: el.body_str.strip
          }.merge(extra)
        end
      end

      if fmt == "json"
        say JSON.pretty_generate(records)
      else
        keys = %i[date ref type tags body] +
               (records.flat_map(&:keys) - %i[date ref type tags body]).uniq
        say CSV.generate { |csv|
          csv << keys.map(&:to_s)
          records.each { |r| csv << keys.map { |k| r[k] } }
        }
      end
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
