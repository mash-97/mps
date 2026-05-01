# frozen_string_literal: true

require_relative 'test_helper'

# Tests that exercise real-world .mps file patterns from test/assets/.
# These are the files that exposed the no-bracket parsing bug.
class AssetsTest < Minitest::Test
  include MPS

  ASSETS_DIR = File.expand_path("assets", __dir__)

  NO_BRACKETS_FILE   = "20260101.1000000001.mps"  # bare @element{ } syntax
  MIXED_FILE         = "20260102.1000000002.mps"  # brackets + no-brackets mix
  DEEPLY_NESTED_FILE = "20260103.1000000003.mps"  # 3-level nesting

  def parse_file(name)
    path = File.join(ASSETS_DIR, name)
    element_classes = Elements.constants
      .map    { |k| Elements.const_get(k) }
      .select { |x| x.class == Class }
    Engines::Parser.parse_mps_file_to_elements_hash(path, element_classes)
  end

  def non_mps(elements)
    elements.values.reject { |e| e.is_a?(Elements::MPS) }
  end

  # ── no_brackets.mps ────────────────────────────────────────────────────────

  def test_no_brackets_task_parsed
    els = non_mps(parse_file(NO_BRACKETS_FILE))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    assert_equal 1, tasks.size
    assert_equal "a bare task with no brackets", tasks.first.body_str.strip
  end

  def test_no_brackets_all_types_parsed
    els = non_mps(parse_file(NO_BRACKETS_FILE))
    assert_equal 1, els.count { |e| e.is_a?(Elements::Task) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Note) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Reminder) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Log) }
  end

  # ── mixed.mps ──────────────────────────────────────────────────────────────

  def test_mixed_outer_task_with_tags
    els = non_mps(parse_file(MIXED_FILE))
    outer = els.select { |e| e.is_a?(Elements::Task) }
               .find { |e| e.tags.include?("x") }
    refute_nil outer, "outer task with tags x,y not found"
    assert_includes outer.tags, "y"
  end

  def test_mixed_nested_task_inside_tagged_task
    els = non_mps(parse_file(MIXED_FILE))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    assert tasks.size >= 2, "expected at least 2 tasks (outer + nested)"
    nested = tasks.find { |e| e.body_str.strip == "it's a nested task with no brackets" }
    refute_nil nested, "nested no-bracket task not found"
  end

  def test_mixed_reminder_with_at_arg
    els = non_mps(parse_file(MIXED_FILE))
    reminders = els.select { |e| e.is_a?(Elements::Reminder) }
    assert_equal 1, reminders.size
    assert_equal "5pm", reminders.first.parsed_args[:at]
  end

  def test_mixed_log_with_tags
    els = non_mps(parse_file(MIXED_FILE))
    logs = els.select { |e| e.is_a?(Elements::Log) }
    assert_equal 1, logs.size
    assert_includes logs.first.tags, "work"
    assert_includes logs.first.tags, "backend"
  end

  def test_mixed_nested_task_inside_mps_block
    els = non_mps(parse_file(MIXED_FILE))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    inside_mps = tasks.find { |e| e.body_str.strip == "Nested task inside a sub-block" }
    refute_nil inside_mps, "task nested inside @mps{} not found"
  end

  def test_mixed_nested_note_inside_mps_block
    els = non_mps(parse_file(MIXED_FILE))
    notes = els.select { |e| e.is_a?(Elements::Note) }
    inside_mps = notes.find { |e| e.body_str.strip == "Nested note inside a sub-block" }
    refute_nil inside_mps, "note nested inside @mps{} not found"
  end

  def test_mixed_total_element_count
    els = non_mps(parse_file(MIXED_FILE))
    # outer task, nested task (in outer), reminder, log, nested task (in mps), nested note (in mps)
    assert_equal 6, els.size
  end

  # ── deeply_nested.mps ──────────────────────────────────────────────────────

  def test_deeply_nested_log_inside_task
    els = non_mps(parse_file(DEEPLY_NESTED_FILE))
    logs = els.select { |e| e.is_a?(Elements::Log) }
    assert_equal 1, logs.size
    assert_equal "nested log inside task", logs.first.body_str.strip
  end

  def test_deeply_nested_note_inside_task
    els = non_mps(parse_file(DEEPLY_NESTED_FILE))
    notes = els.select { |e| e.is_a?(Elements::Note) }
    assert_equal 1, notes.size
    assert_equal "nested note inside task", notes.first.body_str.strip
  end

  def test_deeply_nested_three_levels
    els = non_mps(parse_file(DEEPLY_NESTED_FILE))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    deep = tasks.find { |e| e.body_str.strip == "deeply nested task" }
    refute_nil deep, "3-level nested task not found"
  end

  def test_deeply_nested_task_with_tags_inside_mps
    els = non_mps(parse_file(DEEPLY_NESTED_FILE))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    tagged = tasks.find { |e| e.tags.include?("work") }
    refute_nil tagged, "task[work] inside @mps not found"
    assert_equal "task inside mps block", tagged.body_str.strip
  end
end
