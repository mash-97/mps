# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "tags [DATESIGN]", "Show tag usage table with frequency bars"
  method_option :type,   type: :string,  aliases: "-t", desc: "Filter by element type"
  method_option :since,  type: :string,  aliases: "-S", desc: "From SINCE up to DATESIGN"
  method_option :status, type: :string,  aliases: "-s", desc: "Filter tasks by status"
  method_option :all,    type: :boolean, aliases: "-a", default: false,
                         desc: "Count tags across all dates"
  def tags(datesign = "today")
    init
    begin
      dates = if options[:all] && options[:since]
        since_date = ::MPS.get_date(options[:since]).to_date
        store.all_files.map { |f| Date.strptime(File.basename(f)[0, 8], "%Y%m%d") }
             .uniq.sort.select { |d| d >= since_date }
      elsif options[:all]
        store.all_files.map { |f| Date.strptime(File.basename(f)[0, 8], "%Y%m%d") }.uniq.sort
      elsif options[:since]
        date_range(options[:since], ::MPS.get_date(datesign))
      else
        [::MPS.get_date(datesign).to_date]
      end

      q      = ::MPS::Query.new(options)
      counts = Hash.new(0)
      dates.each do |d|
        q.apply(store.parse_date(d)).each_value do |el|
          el.tags.each { |t| counts[t] += 1 }
        end
      end

      if counts.empty?
        say set_color("(no tags found)", :yellow)
        return
      end

      sorted  = counts.sort_by { |_, v| -v }
      max_cnt = sorted.first[1]
      max_tag = sorted.map(&:first).map(&:length).max
      bar_max = 24

      say set_color("  #{"Tag".ljust(max_tag)}  Count  Frequency", :white)
      say set_color("  #{"-" * max_tag}  -----  #{"-" * bar_max}", :white)
      sorted.each do |tag, n|
        bar_len = (n.to_f / max_cnt * bar_max).ceil
        bar     = set_color("█" * bar_len, :cyan)
        say "  #{set_color(tag.ljust(max_tag), :white)}  #{n.to_s.rjust(5)}  #{bar}"
      end
      total = counts.values.sum
      say ""
      say set_color("  #{sorted.size} tag#{sorted.size == 1 ? '' : 's'}, #{total} total uses", :white)
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
