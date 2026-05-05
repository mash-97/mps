# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "list [DATESIGN]", "List elements for a date (default: today)"
  method_option :type,           type: :string,  aliases: "-t",
                                 desc: "Filter by type: task, note, log, reminder"
  method_option :tag,            type: :string,  aliases: "-g", desc: "Filter by tag"
  method_option :status,         type: :string,  aliases: "-s",
                                 desc: "Filter tasks by status: open, done"
  method_option :since,          type: :string,  aliases: "-S",
                                 desc: "Show elements from SINCE up to DATESIGN"
  method_option :refs,           type: :boolean, aliases: "-r", default: false,
                                 desc: "Show human-readable ref column"
  method_option :all,            type: :boolean, aliases: "-a", default: false,
                                 desc: "List elements across all dates"
  method_option :per_line_space, type: :numeric, default: 0,
                                 desc: "Blank lines after each element (default: 0)"
  method_option :per_date_space, type: :numeric, default: 0,
                                 desc: "Blank lines after each date block"
  def list(datesign = "today")
    init
    begin
      all_dates = store.all_files
                       .map { |f| Date.strptime(File.basename(f)[0, 8], "%Y%m%d") }
                       .uniq.sort
      dates = if options[:all] && options[:since]
        since_date = ::MPS.get_date(options[:since]).to_date
        all_dates.select { |d| d >= since_date }
      elsif options[:all]
        all_dates
      elsif options[:since]
        date_range(options[:since], ::MPS.get_date(datesign))
      else
        [::MPS.get_date(datesign).to_date]
      end

      per_line  = options[:per_line_space].to_i
      per_date  = options[:per_date_space].to_i
      shown     = 0
      multi     = dates.size > 1

      dates.each_with_index do |d, idx|
        all = store.parse_date(d)
        next if all.empty?
        resolver = options[:refs] ? ::MPS::RefResolver.new(all) : nil
        count = print_tree(all, options, resolver: resolver, per_line_space: per_line,
                           header: multi ? d.strftime("%Y-%m-%d") : nil)
        shown += count
        per_date.times { say "" } if multi && count > 0 && idx < dates.size - 1
      end
      say set_color("(no elements found)", :yellow) if shown.zero?
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
