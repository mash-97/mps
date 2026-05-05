# frozen_string_literal: true

require "thor"
require "yaml"
require "json"
require "csv"
require "cli/ui"

module MPS
  module CLI
    # Root Thor dispatcher. All commands self-register via class_eval from
    # lib/mps/cli/commands/*.rb — adding a command means adding a file there.
    class MPS < Thor
      include Thor::Actions
      class_option :verbose,     type: :boolean, default: false
      class_option :config_path, type: :string,  default: ::MPS::Constants::MPS_CONFIG_FILE,
                                                 desc: "mps config file path"
      class_option :force,       type: :boolean, default: false

      default_task :open
      VALID_TYPES = %w[task note log reminder].freeze

      def self.exit_on_failure? = true

      # Intercept bare invocation to honour config's default_command.
      def self.start(given_args = ARGV, config = {})
        if given_args.empty?
          begin
            conf = ::MPS::Config.load_conf_hash(::MPS::Constants::MPS_CONFIG_FILE)
            default = conf.fetch(:default_command, "open").to_s
            return super(["list"] + given_args, config) if default == "list"
          rescue StandardError
            # Config may not exist yet — fall through to normal start
          end
        end
        super
      end

      # ── version (stays here — it's tiny and infrastructure) ───────────────

      desc "version", "Print version"
      def version
        say "mps (v#{::MPS::VERSION})"
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

      # ── store / resolver helpers ───────────────────────────────────────────

      def store
        @store ||= ::MPS::Store.new(@config.storage_dir)
      end

      def resolver_for(date)
        ::MPS::RefResolver.new(store.parse_date(date))
      end

      # ── date helpers ───────────────────────────────────────────────────────

      def date_range(since_str, to_date)
        since_date = ::MPS.get_date(since_str).to_date
        (since_date..to_date.to_date).to_a
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

      # Formats integer minutes as "Xh" or "XhYm".
      def format_duration(minutes)
        return "" unless minutes && minutes > 0
        h, m = minutes.divmod(60)
        m > 0 ? "#{h}h#{m}m" : "#{h}h"
      end

      def print_element(el, depth: 0, ref: nil)
        indent    = "  " * (depth + 1)
        type_name = el.class::SIGNATURE_STAMP
        tags_str  = el.tags.empty? ? "" : " #{set_color("[#{el.tags.join(', ')}]", :white)}"
        body_line = el.body_str.strip.lines.first&.strip
        ref_col   = ref ? "#{set_color(ref.ljust(12), :white)}  " : ""
        say "#{indent}#{ref_col}#{type_badge(type_name)} #{element_extra(el)}#{body_line}#{tags_str}"
      end

      # Renders elements_hash as indented tree; returns printed count.
      # +header+ is printed once (lazily) before the first visible element, if set.
      def print_tree(elements_hash, opts, resolver: nil, per_line_space: 0, header: nil)
        q      = ::MPS::Query.new(opts)
        sorted = elements_hash.sort_by { |k, _| k.split(".").map(&:to_i) }
        return 0 if sorted.empty?

        root_segs    = sorted.first.first.split(".").size
        show_refs    = opts[:refs]
        shown        = 0
        header_shown = false

        sorted.each do |ref_key, el|
          depth = ref_key.split(".").size - root_segs - 1
          next if depth < 0

          if el.is_a?(::MPS::Elements::MPS)
            prefix = "#{ref_key}."
            any_visible = elements_hash.any? do |k, v|
              k.start_with?(prefix) && !v.is_a?(::MPS::Elements::MPS) && q.match?(v)
            end
            next unless any_visible
            unless header_shown
              say set_color("── #{header} ─────────────", :white) if header
              header_shown = true
            end
            indent    = "  " * (depth + 1)
            human_ref = resolver&.to_human(ref_key) || ref_key
            ref_col   = show_refs ? "#{set_color(human_ref.ljust(12), :white)}  " : ""
            say "#{indent}#{ref_col}#{set_color("[@mps]", :white)}"
          else
            next unless q.match?(el)
            unless header_shown
              say set_color("── #{header} ─────────────", :white) if header
              header_shown = true
            end
            human_ref = resolver&.to_human(ref_key) || ref_key
            ref_col   = show_refs ? human_ref : nil
            print_element(el, depth: depth, ref: ref_col)
            per_line_space.times { say "" }
            shown += 1
          end
        end
        shown
      end

      # ── git helpers ────────────────────────────────────────────────────────

      def auto_git_cmd
        "git add . && git commit -m \"$(date)\" && " \
        "git pull #{@config.git_remote} #{@config.git_branch} && " \
        "git push #{@config.git_remote} #{@config.git_branch}"
      end

      # ── type alias resolution ──────────────────────────────────────────────

      def resolve_type(raw_type)
        normalized = raw_type.downcase
        aliases    = (@config.type_aliases || {}).transform_keys(&:to_s)
        aliases.fetch(normalized, normalized)
      end
    end
  end
end
