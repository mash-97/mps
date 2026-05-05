# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "stats [DATESIGN]", "Show element counts and log durations"
  method_option :since,  type: :string,  aliases: "-S", desc: "Stats from SINCE up to DATESIGN"
  method_option :all,    type: :boolean, aliases: "-a", default: false,
                         desc: "Stats across all dates"
  def stats(datesign = "today")
    init
    begin
      dates = if options[:all] && options[:since]
        since_date = ::MPS.get_date(options[:since]).to_date
        store.all_files.map { |f| Date.strptime(File.basename(f)[0, 8], "%Y%m%d") }
             .uniq.sort.select { |d| d >= since_date }
      elsif options[:all]
        store.all_files.map { |f| Date.strptime(File.basename(f)[0, 8], "%Y%m%d") }.uniq.sort
      elsif options[:since]
        date  = ::MPS.get_date(datesign)
        date_range(options[:since], date)
      else
        date  = ::MPS.get_date(datesign)
        [date.to_date]
      end

      total          = Hash.new(0)
      total_log_mins = 0
      any            = false

      dates.each do |d|
        elements = store.parse_date(d).values
                        .reject { |e| e.is_a?(::MPS::Elements::MPS) || e.is_a?(::MPS::Engines::Parser::Unknown) }
        next if elements.empty?
        any    = true
        counts = elements.group_by { |e| e.class::SIGNATURE_STAMP }.transform_values(&:size)
        log_mins = elements.select { |e| e.is_a?(::MPS::Elements::Log) }
                           .sum { |e| e.duration_minutes || 0 }
        tasks    = elements.select { |e| e.is_a?(::MPS::Elements::Task) }

        parts = []
        if (n = counts["task"])
          open_n = tasks.count(&:open?)
          done_n = tasks.count(&:done?)
          parts << "#{n} task#{n != 1 ? 's' : ''} " \
                   "(#{set_color("#{open_n} open", :yellow)}, " \
                   "#{set_color("#{done_n} done", :green)})"
        end
        parts << "#{counts['note']} note#{counts['note'] != 1 ? 's' : ''}"               if counts["note"]
        parts << "#{counts['reminder']} reminder#{counts['reminder'] != 1 ? 's' : ''}"   if counts["reminder"]
        if (n = counts["log"])
          dur_str = format_duration(log_mins)
          parts << "#{n} log#{n != 1 ? 's' : ''}#{dur_str.empty? ? '' : " (#{dur_str})"}"
        end

        say "#{set_color(d.strftime('%Y-%m-%d'), :white)} — #{parts.join(', ')}"
        counts.each { |k, v| total[k] += v }
        total_log_mins += log_mins
      end

      say set_color("(no data found)", :yellow) unless any

      if dates.size > 1 && any
        say set_color("─" * 44, :white)
        tparts = []
        tparts << "#{total['task']} tasks"         if total["task"] > 0
        tparts << "#{total['note']} notes"         if total["note"] > 0
        tparts << "#{total['reminder']} reminders" if total["reminder"] > 0
        if total["log"] > 0
          dur_str = format_duration(total_log_mins)
          tparts << "#{total['log']} logs#{dur_str.empty? ? '' : " (#{dur_str} total)"}"
        end
        say "Total: #{tparts.join(', ')}"
      end
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
