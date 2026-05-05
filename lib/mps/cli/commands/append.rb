# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "append TYPE BODY", "Append an element to today's file without opening Vim"
  method_option :tags,       type: :string, desc: "Comma-separated tags (e.g. work,release)"
  method_option :status,     type: :string, desc: "Task status: open (default) or done"
  method_option :at,         type: :string, desc: "Time for reminders (e.g. '3pm')"
  method_option :start_time, type: :string, desc: "Start time for logs (HH:MM)"
  method_option :end_time,   type: :string, desc: "End time for logs (HH:MM)"
  def append(type, *body_parts)
    init
    begin
      type = resolve_type(type)
      unless ::MPS::CLI::MPS::VALID_TYPES.include?(type)
        raise Thor::Error, "Unknown type '#{type}'. Valid: #{::MPS::CLI::MPS::VALID_TYPES.join(', ')}"
      end
      body  = body_parts.join(" ")
      tags  = options[:tags]&.split(",")&.map(&:strip) || []
      attrs = {}
      attrs[:status] = options[:status]     if options[:status]
      attrs[:at]     = options[:at]          if options[:at]
      attrs[:start]  = options[:start_time]  if options[:start_time]
      attrs[:end]    = options[:end_time]    if options[:end_time]

      path = store.append(type: type, body: body, tags: tags, attrs: attrs)
      say_status :appended, "#{type_badge(type)} #{body}", :green
      @config.logger.info("Appended #{type} to #{File.basename(path)}\n")
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
