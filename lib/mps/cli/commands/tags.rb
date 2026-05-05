# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "tags [DATESIGN]", "Show tag usage counts (equivalent to mps list tags)"
  method_option :type,  type: :string, aliases: "-t", desc: "Filter by element type"
  method_option :since, type: :string, aliases: "-S", desc: "From SINCE up to DATESIGN"
  method_option :status, type: :string, aliases: "-s", desc: "Filter tasks by status"
  def tags(datesign = "today")
    init
    begin
      date  = ::MPS.get_date(datesign)
      dates = options[:since] ? date_range(options[:since], date) : [date.to_date]
      q     = ::MPS::Query.new(options)

      counts = Hash.new(0)
      dates.each do |d|
        q.apply(store.parse_date(d)).each_value do |el|
          el.tags.each { |t| counts[t] += 1 }
        end
      end

      if counts.empty?
        say set_color("(no tags found)", :yellow)
      else
        counts.sort_by { |_, v| -v }.each do |tag, n|
          say "  #{set_color(tag, :white)} (#{n})"
        end
      end
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
