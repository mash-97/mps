# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'json'
require 'csv'
require 'cli/ui'

module MPS
  module CLI
    class MPS < Thor
      include Thor::Actions
      class_option :verbose,     type: :boolean, default: false
      class_option :config_path, type: :string,  default: ::MPS::Constants::MPS_CONFIG_FILE,
                                                 desc: "mps config file path"
      class_option :force,       type: :boolean, default: false
      default_task :open

      VALID_TYPES = %w[task note log reminder].freeze

      def self.exit_on_failure?
        true
      end

      # ── version ────────────────────────────────────────────────────────────

      desc "version", "Print version"
      def version
        say "mps (v#{::MPS::VERSION})"
      end

      # ── open ───────────────────────────────────────────────────────────────

      desc "open [DATESIGN]", "Open .mps file in editor (default: today)"
      def open(datesign = "today")
        init
        begin
          date  = ::MPS.get_date(datesign)
          store = ::MPS::Store.new(@config.storage_dir)
          files = store.find_files(date)
          file_path = if files.size > 1
            ::CLI::UI::Prompt.ask("#{files.size} files found:") do |h|
              files.each { |f| h.option(File.basename(f)) { |_| f } }
            end
          else
            store.find_or_create_path(date)
          end
          @config.logger.info("Open MPS in text editor\n")
          written = ::MPS.open_editor(file_path)
          @config.logger.info("Done written Size: #{written} bytes\n")
          say_status :written, "#{written} bytes", :green
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      # ── list ───────────────────────────────────────────────────────────────

      desc "list [DATESIGN]", "List elements for a date (default: today)"
      method_option :type,   type: :string,  aliases: "-t",
                             desc: "Filter by type: task, note, log, reminder"
      method_option :tag,    type: :string,  aliases: "-g", desc: "Filter by tag"
      method_option :status, type: :string,  aliases: "-s",
                             desc: "Filter tasks by status: open, done"
      method_option :since,  type: :string,  aliases: "-S",
                             desc: "Show elements from SINCE up to DATESIGN"
      def list(datesign = "today")
        init
        begin
          store = ::MPS::Store.new(@config.storage_dir)
          date  = ::MPS.get_date(datesign)
          dates = options[:since] ? date_range(options[:since], date) : [date.to_date]

          shown = 0
          dates.each do |d|
            all = store.parse_date(d)
            next if all.empty?
            say set_color("── #{d.strftime('%Y-%m-%d')} ─────────────", :white) if dates.size > 1
            shown += print_tree(all, options)
          end
          say set_color("(no elements found)", :yellow) if shown.zero?
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      # ── append ─────────────────────────────────────────────────────────────

      desc "append TYPE BODY", "Append an element to today's file without opening Vim"
      method_option :tags,       type: :string, desc: "Comma-separated tags (e.g. work,release)"
      method_option :status,     type: :string, desc: "Task status: open (default) or done"
      method_option :at,         type: :string, desc: "Time for reminders (e.g. '3pm')"
      method_option :start_time, type: :string, desc: "Start time for logs (HH:MM)"
      method_option :end_time,   type: :string, desc: "End time for logs (HH:MM)"
      def append(type, *body_parts)
        init
        begin
          type = type.downcase
          unless VALID_TYPES.include?(type)
            raise Thor::Error, "Unknown type '#{type}'. Valid: #{VALID_TYPES.join(', ')}"
          end
          body  = body_parts.join(" ")
          tags  = options[:tags]&.split(",")&.map(&:strip) || []
          attrs = {}
          attrs[:status] = options[:status]     if options[:status]
          attrs[:at]     = options[:at]          if options[:at]
          attrs[:start]  = options[:start_time]  if options[:start_time]
          attrs[:end]    = options[:end_time]    if options[:end_time]

          store = ::MPS::Store.new(@config.storage_dir)
          path  = store.append(type: type, body: body, tags: tags, attrs: attrs)
          say_status :appended, "#{type_badge(type)} #{body}", :green
          @config.logger.info("Appended #{type} to #{File.basename(path)}\n")
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      # ── search ─────────────────────────────────────────────────────────────

      desc "search QUERY", "Full-text search across all .mps files"
      method_option :type,  type: :string, aliases: "-t", desc: "Filter by type"
      method_option :tag,   type: :string, aliases: "-g", desc: "Filter by tag"
      method_option :since, type: :string, aliases: "-S", desc: "Search from this date onward"
      def search(query)
        init
        begin
          store      = ::MPS::Store.new(@config.storage_dir)
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

      # ── stats ──────────────────────────────────────────────────────────────

      desc "stats [DATESIGN]", "Show element counts and log durations"
      method_option :since, type: :string, aliases: "-S",
                            desc: "Stats from SINCE up to DATESIGN"
      def stats(datesign = "today")
        init
        begin
          store  = ::MPS::Store.new(@config.storage_dir)
          date   = ::MPS.get_date(datesign)
          dates  = options[:since] ? date_range(options[:since], date) : [date.to_date]

          total  = Hash.new(0)
          total_log_mins = 0
          any = false

          dates.each do |d|
            elements = store.parse_date(d).values
                         .reject { |e| e.is_a?(::MPS::Elements::MPS) }
            next if elements.empty?
            any = true
            counts   = elements.group_by { |e| e.class::SIGNATURE_STAMP }.transform_values(&:size)
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
            parts << "#{counts['note']} note#{counts['note'] != 1 ? 's' : ''}"       if counts["note"]
            parts << "#{counts['reminder']} reminder#{counts['reminder'] != 1 ? 's':''}" if counts["reminder"]
            if (n = counts["log"])
              h, m = log_mins.divmod(60)
              dur  = log_mins > 0 ? " (#{h}h#{m > 0 ? "#{m}m" : ""})" : ""
              parts << "#{n} log#{n != 1 ? 's' : ''}#{dur}"
            end

            say "#{set_color(d.strftime('%Y-%m-%d'), :white)} — #{parts.join(', ')}"
            counts.each { |k, v| total[k] += v }
            total_log_mins += log_mins
          end

          say set_color("(no data found)", :yellow) unless any

          if dates.size > 1 && any
            say set_color("─" * 44, :white)
            tparts = []
            tparts << "#{total['task']} tasks"      if total["task"] > 0
            tparts << "#{total['note']} notes"      if total["note"] > 0
            tparts << "#{total['reminder']} reminders" if total["reminder"] > 0
            if total["log"] > 0
              h, m = total_log_mins.divmod(60)
              dur  = total_log_mins > 0 ? " (#{h}h#{m > 0 ? "#{m}m" : ""} total)" : ""
              tparts << "#{total['log']} logs#{dur}"
            end
            say "Total: #{tparts.join(', ')}"
          end
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      # ── export ─────────────────────────────────────────────────────────────

      desc "export [DATESIGN]", "Export elements to JSON or CSV (writes to stdout)"
      method_option :format, type: :string, default: "json", aliases: "-f",
                             desc: "Output format: json, csv"
      method_option :type,   type: :string, aliases: "-t", desc: "Filter by type"
      method_option :since,  type: :string, aliases: "-S",
                             desc: "Export from SINCE up to DATESIGN"
      def export(datesign = "today")
        init
        begin
          store = ::MPS::Store.new(@config.storage_dir)
          date  = ::MPS.get_date(datesign)
          dates = options[:since] ? date_range(options[:since], date) : [date.to_date]
          fmt   = options[:format].downcase

          unless %w[json csv].include?(fmt)
            raise Thor::Error, "Unknown format '#{fmt}'. Use: json, csv"
          end

          records = []
          dates.each do |d|
            store.parse_date(d).each do |ref, el|
              next if el.is_a?(::MPS::Elements::MPS)
              next if options[:type] && el.class::SIGNATURE_STAMP != options[:type].downcase
              extra = el.parsed_args.reject { |k, _| k == :tags }
              records << {
                date:  d.strftime("%Y-%m-%d"),
                ref:   ref,
                type:  el.class::SIGNATURE_STAMP,
                tags:  el.tags.join(","),
                body:  el.body_str.strip
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

      # ── git / autogit / cmd ────────────────────────────────────────────────

      desc "git GITCOMMAND", "Run git commands inside storage_dir"
      def git(*commands)
        init
        begin
          git_command = if commands.first == "auto"
            "git add . && git commit -m \"$(date)\" && " \
            "git pull #{@config.git_remote} #{@config.git_branch} && " \
            "git push #{@config.git_remote} #{@config.git_branch}"
          elsif commands.first == "autocommit"
            "git add . && git commit -m \"$(date)\""
          elsif commands.size > 0
            cmds = commands.map { |c| c.include?(" ") ? "\"#{c}\"" : c }
            "git #{cmds.join(' ')}"
          else
            "git status"
          end
          inside(@config.storage_dir) { run git_command }
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      desc "autogit", "Auto stage, commit, pull and push"
      def autogit
        init
        begin
          cmd = "git add . && git commit -m \"$(date)\" && " \
                "git pull #{@config.git_remote} #{@config.git_branch} && " \
                "git push #{@config.git_remote} #{@config.git_branch}"
          inside(@config.storage_dir) { run cmd }
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      desc "cmd COMMAND", "Run shell commands inside storage_dir"
      def cmd(*commands)
        init
        begin
          cmds = commands.map { |c| c.include?(" ") ? "\"#{c}\"" : c }
          inside(@config.storage_dir) { run cmds.join(" ") }
        rescue StandardError => e
          raise Thor::Error, e
        end
      end

      private

      # ── config helpers ─────────────────────────────────────────────────────

      def init
        @config = load_config(options[:config_path], force: options[:force])
      rescue StandardError => e
        say_status "error", "failed to initialize"
        raise Thor::Error, e
      end

      def load_config(config_path, force: false)
        ::MPS::Config.init(config_path) if !File.exist?(config_path) || force
        ::MPS::Config.new(**load_tangible_config_hash(config_path))
      end

      def load_tangible_config_hash(config_path)
        conf_hash = ::MPS::Config.load_conf_hash(config_path)
        empty_directory conf_hash[:storage_dir] unless Dir.exist?(conf_hash[:storage_dir])
        empty_directory conf_hash[:mps_dir]     unless Dir.exist?(conf_hash[:mps_dir])
        create_file     conf_hash[:log_file]    unless File.exist?(conf_hash[:log_file])
        conf_hash
      end

      # ── display helpers ────────────────────────────────────────────────────

      TYPE_COLORS = {
        "task"     => :green,
        "note"     => :cyan,
        "reminder" => :magenta,
        "log"      => :yellow
      }.freeze

      def type_badge(type_name)
        color = TYPE_COLORS.fetch(type_name, :white)
        set_color("[#{type_name}]", color)
      end

      def element_extra(el)
        case el
        when ::MPS::Elements::Task
          status = el.parsed_args[:status] || "open"
          color  = status == "done" ? :green : :yellow
          "(#{set_color(status, color)}) "
        when ::MPS::Elements::Log
          dur = el.duration_str
          dur ? "(#{set_color(dur, :yellow)}) " : ""
        when ::MPS::Elements::Reminder
          at = el.parsed_args[:at]
          at ? "(#{set_color(at, :magenta)}) " : ""
        else
          ""
        end
      end

      def print_element(el, depth: 0)
        indent    = "  " * (depth + 1)
        type_name = el.class::SIGNATURE_STAMP
        tags_str  = el.tags.empty? ? "" : " #{set_color("[#{el.tags.join(', ')}]", :white)}"
        body_line = el.body_str.strip.lines.first&.strip
        say "#{indent}#{type_badge(type_name)} #{element_extra(el)}#{body_line}#{tags_str}"
      end

      # Renders elements_hash as an indented tree ordered by ref path.
      # @mps containers show as group headers; the synthetic root wrapper is skipped.
      # Returns the count of non-MPS elements actually printed.
      def print_tree(elements_hash, opts)
        sorted = elements_hash.sort_by { |k, _| k.split(".").map(&:to_i) }
        return 0 if sorted.empty?

        root_segs = sorted.first.first.split(".").size  # always 1 (just the epoch)
        shown = 0

        sorted.each do |ref_key, el|
          depth = ref_key.split(".").size - root_segs - 1
          next if depth < 0  # root synthetic @mps wrapper

          if el.is_a?(::MPS::Elements::MPS)
            # Only show @mps group header when it has at least one visible child.
            prefix = "#{ref_key}."
            any_visible = elements_hash.any? do |k, v|
              k.start_with?(prefix) && !v.is_a?(::MPS::Elements::MPS) && visible?(v, opts)
            end
            next unless any_visible
            indent = "  " * (depth + 1)
            say "#{indent}#{set_color("[@mps]", :white)}"
          else
            next unless visible?(el, opts)
            print_element(el, depth: depth)
            shown += 1
          end
        end
        shown
      end

      def visible?(el, opts)
        type_f   = opts[:type]&.downcase
        tag_f    = opts[:tag]
        status_f = opts[:status]
        return false if type_f   && el.class::SIGNATURE_STAMP != type_f
        return false if tag_f    && !el.tags.include?(tag_f)
        # --status only matches elements that carry a status field (i.e. tasks)
        if status_f
          s = el.respond_to?(:parsed_args) ? el.parsed_args[:status] : nil
          return false if s.nil? || s != status_f
        end
        true
      end

      # ── filtering (used by search/stats helpers) ────────────────────────────

      def filtered_elements(elements_hash, opts)
        elements_hash.values
          .reject { |e| e.is_a?(::MPS::Elements::MPS) }
          .select { |e| visible?(e, opts) }
      end

      def date_range(since_str, to_date)
        since_date = ::MPS.get_date(since_str).to_date
        (since_date..to_date.to_date).to_a
      end
    end
  end
end
