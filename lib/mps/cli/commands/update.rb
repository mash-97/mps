# frozen_string_literal: true

MPS::CLI::MPS.class_eval do
  # Returns all schema-declared attribute definitions across every element type.
  # Called at class-load time (for method_option registration) and at call time
  # (inside the update method body). A class method survives both contexts.
  def self._schema_update_attrs
    ::MPS::Elements.constants
      .map    { |k| ::MPS::Elements.const_get(k) }
      .select { |x| x.class == Class }
      .flat_map { |klass| klass.schema.to_a }
      .uniq { |name, _| name }
      .select { |_, defn| defn[:flag] }
  end

  desc "update REFPATH", "Update an element's attributes in-place"
  _schema_update_attrs.each do |_name, defn|
    method_option defn[:flag], type: :string, desc: "Set #{defn[:flag]}"
  end
  method_option :date, type: :string, aliases: "-d",
                       desc: "Date context for human refs (default: today)"
  def update(ref_path)
    init
    begin
      date = options[:date] ? ::MPS.get_date(options[:date]).to_date : Date.today
      new_attrs = {}
      self.class._schema_update_attrs.each do |name, defn|
        flag_sym = defn[:flag].tr("-", "_").to_sym
        new_attrs[name] = options[flag_sym] if options[flag_sym]
      end
      raise Thor::Error, "No attributes specified." if new_attrs.empty?

      unless store.rewrite_element(ref_path, new_attrs, date: date)
        raise Thor::Error, "Could not update '#{ref_path}'. Check the ref is correct."
      end
      say_status :updated, ref_path, :green
    rescue StandardError => e
      raise Thor::Error, e
    end
  end

  desc "done REFPATH", "Mark a task as done (shorthand for update REFPATH --status done)"
  method_option :date, type: :string, aliases: "-d",
                       desc: "Date context for human refs (default: today)"
  def done(ref_path)
    init
    begin
      date = options[:date] ? ::MPS.get_date(options[:date]).to_date : Date.today
      unless store.rewrite_element(ref_path, { status: "done" }, date: date)
        raise Thor::Error, "Could not mark '#{ref_path}' as done. Check the ref is correct."
      end
      say_status :done, ref_path, :green
    rescue StandardError => e
      raise Thor::Error, e
    end
  end
end
