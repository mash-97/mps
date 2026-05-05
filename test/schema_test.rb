# frozen_string_literal: true

require_relative "test_helper"

# Schema DSL and parse/serialize symmetry tests.
class SchemaTest < Minitest::Test
  include MPS

  # ── attribute DSL ───────────────────────────────────────────────────────────

  def test_task_schema_declares_status
    s = Elements::Task.schema
    assert s.key?(:status), "Task schema should have :status"
    assert_equal :string,  s[:status][:type]
    assert_equal "open",   s[:status][:default]
    assert_equal "status", s[:status][:flag]
  end

  def test_log_schema_declares_start_and_end
    s = Elements::Log.schema
    assert s.key?(:start), "Log schema should have :start"
    assert s.key?(:end),   "Log schema should have :end"
    assert_equal "start-time", s[:start][:flag]
    assert_equal "end-time",   s[:end][:flag]
  end

  def test_reminder_schema_declares_at
    s = Elements::Reminder.schema
    assert s.key?(:at), "Reminder schema should have :at"
    assert_equal "at", s[:at][:flag]
  end

  def test_note_schema_is_empty
    assert Elements::Note.schema.empty?, "Note should have no typed attributes"
  end

  def test_mps_schema_is_empty
    assert Elements::MPS.schema.empty?, "MPS container should have no typed attributes"
  end

  # ── schema-driven parse_args ─────────────────────────────────────────────────

  def test_task_parses_status_from_schema
    t = Elements::Task.new(args: "work, status: done", refs: [1], body_str: "x")
    assert_equal "done",   t.parsed_args[:status]
    assert_equal %w[work], t.parsed_args[:tags]
  end

  def test_task_default_status_open_from_schema
    t = Elements::Task.new(args: "work", refs: [1], body_str: "x")
    assert_equal "open", t.parsed_args[:status]
  end

  def test_log_parses_start_end_from_schema
    l = Elements::Log.new(args: "work, start: 09:00, end: 12:30", refs: [1], body_str: "x")
    assert_equal "09:00", l.parsed_args[:start]
    assert_equal "12:30", l.parsed_args[:end]
    assert_equal %w[work], l.parsed_args[:tags]
  end

  def test_reminder_parses_at_from_schema
    r = Elements::Reminder.new(args: "work, at: 5pm", refs: [1], body_str: "x")
    assert_equal "5pm",   r.parsed_args[:at]
    assert_equal %w[work], r.parsed_args[:tags]
  end

  # ── symmetry: parse then re-serialize produces same result ─────────────────

  def test_task_serialize_symmetry
    raw = "work, status: done"
    t   = Elements::Task.new(args: raw, refs: [1], body_str: "ship it")
    # Rebuild args string from parsed_args — same structure
    rebuilt = [
      t.parsed_args.reject { |k, _| k == :tags }.map { |k, v| "#{k}: #{v}" },
      t.tags
    ].flatten.join(", ")
    t2 = Elements::Task.new(args: rebuilt, refs: [1], body_str: "ship it")
    assert_equal t.parsed_args[:status], t2.parsed_args[:status]
    assert_equal t.tags,                 t2.tags
  end

  def test_log_serialize_symmetry
    raw = "work, start: 09:00, end: 11:00"
    l   = Elements::Log.new(args: raw, refs: [1], body_str: "focused")
    rebuilt = [
      l.parsed_args.reject { |k, _| k == :tags }.reject { |_, v| v.nil? }.map { |k, v| "#{k}: #{v}" },
      l.tags
    ].flatten.join(", ")
    l2 = Elements::Log.new(args: rebuilt, refs: [1], body_str: "focused")
    assert_equal l.duration_minutes, l2.duration_minutes
    assert_equal l.tags,             l2.tags
  end

  # ── adding a new attribute to Task requires only the schema declaration ─────

  def test_new_attribute_appears_in_parsed_args_without_other_changes
    # Temporarily add :location attribute to Task
    Elements::Task.attribute :location, type: :string, default: nil, flag: "location"
    t = Elements::Task.new(args: "work, location: home", refs: [1], body_str: "remote work")
    assert_equal "home", t.parsed_args[:location]
    assert_equal %w[work], t.tags
  ensure
    # Clean up so we don't pollute other tests
    Elements::Task._schema.delete(:location)
  end

  def test_new_attribute_with_default_nil
    Elements::Task.attribute :priority, type: :string, default: nil, flag: "priority"
    t = Elements::Task.new(args: "work", refs: [1], body_str: "something")
    assert_nil t.parsed_args[:priority]
  ensure
    Elements::Task._schema.delete(:priority)
  end
end
