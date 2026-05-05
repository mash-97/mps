# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  desc "open [DATESIGN]", "Open .mps file in editor (default: today)"
  def open(datesign = "today")
    init
    begin
      date  = ::MPS.get_date(datesign)
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
end
