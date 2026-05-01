# frozen_string_literal: true

require_relative 'test_helper'

class ElementTest < Minitest::Test
  include MPS

  # ── Element.split_args ─────────────────────────────────────────────────────

  def test_split_args_empty
    r = Element.split_args("")
    assert_equal({}, r[:attrs])
    assert_equal([], r[:tags])
  end

  def test_split_args_nil
    r = Element.split_args(nil)
    assert_equal({}, r[:attrs])
    assert_equal([], r[:tags])
  end

  def test_split_args_tags_only
    r = Element.split_args("work, release, personal")
    assert_equal [], r[:attrs].keys
    assert_equal %w[work release personal], r[:tags]
  end

  def test_split_args_attrs_only
    r = Element.split_args("status: done, start: 09:00")
    assert_equal "done",  r[:attrs][:status]
    assert_equal "09:00", r[:attrs][:start]
    assert_equal [], r[:tags]
  end

  def test_split_args_mixed
    r = Element.split_args("work, release, status: done")
    assert_equal "done", r[:attrs][:status]
    assert_equal %w[work release], r[:tags]
  end

  # ── Task ───────────────────────────────────────────────────────────────────

  def test_task_default_status_open
    t = Elements::Task.new(args: "work", refs: [1], body_str: "do thing")
    assert_equal "open", t.parsed_args[:status]
    assert t.open?
    refute t.done?
  end

  def test_task_status_done
    t = Elements::Task.new(args: "work, status: done", refs: [1], body_str: "do thing")
    assert_equal "done", t.parsed_args[:status]
    assert t.done?
    refute t.open?
  end

  def test_task_tags
    t = Elements::Task.new(args: "work, release", refs: [1], body_str: "ship it")
    assert_equal %w[work release], t.tags
  end

  def test_task_no_args
    t = Elements::Task.new(args: "", refs: [1], body_str: "bare task")
    assert_equal "open", t.parsed_args[:status]
    assert_equal [], t.tags
  end

  # ── Note ───────────────────────────────────────────────────────────────────

  def test_note_tags
    n = Elements::Note.new(args: "ideas, personal", refs: [1], body_str: "cool idea")
    assert_equal %w[ideas personal], n.tags
  end

  def test_note_no_tags
    n = Elements::Note.new(args: "", refs: [1], body_str: "plain note")
    assert_equal [], n.tags
  end

  # ── Reminder ───────────────────────────────────────────────────────────────

  def test_reminder_at
    r = Elements::Reminder.new(args: "work, at: 3pm", refs: [1], body_str: "standup")
    assert_equal "3pm", r.parsed_args[:at]
    assert_equal %w[work], r.tags
  end

  def test_reminder_no_at
    r = Elements::Reminder.new(args: "work", refs: [1], body_str: "standup")
    assert_nil r.parsed_args[:at]
  end

  # ── Log ────────────────────────────────────────────────────────────────────

  def test_log_parse_args
    l = Elements::Log.new(args: "work, start: 09:00, end: 12:30", refs: [1], body_str: "deep work")
    assert_equal "09:00", l.parsed_args[:start]
    assert_equal "12:30", l.parsed_args[:end]
    assert_equal %w[work], l.tags
  end

  def test_log_duration_minutes
    l = Elements::Log.new(args: "start: 09:00, end: 12:30", refs: [1], body_str: "work")
    assert_equal 210, l.duration_minutes
  end

  def test_log_duration_str
    l = Elements::Log.new(args: "start: 09:00, end: 12:30", refs: [1], body_str: "work")
    assert_equal "3h30m", l.duration_str
  end

  def test_log_duration_str_exact_hours
    l = Elements::Log.new(args: "start: 09:00, end: 11:00", refs: [1], body_str: "work")
    assert_equal "2h", l.duration_str
  end

  def test_log_duration_nil_without_times
    l = Elements::Log.new(args: "work", refs: [1], body_str: "work")
    assert_nil l.duration_minutes
    assert_nil l.duration_str
  end

  # ── tags accessor via Element mixin ────────────────────────────────────────

  def test_tags_fallback_empty_for_type_without_parse_args
    # MPS element has parse_args but let's verify tags works generically
    m = Elements::MPS.new(args: "personal", refs: [1], body_str: "")
    assert_equal %w[personal], m.tags
  end

  # ── raw_args preserved ─────────────────────────────────────────────────────

  def test_raw_args_stored
    t = Elements::Task.new(args: "work, status: done", refs: [1], body_str: "x")
    assert_equal "work, status: done", t.raw_args
  end
end
