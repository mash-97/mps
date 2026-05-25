# frozen_string_literal: true

require_relative "test_helper"

# Edge-case tests against the new fixture files added in the 2026-05 test expansion.
# Each fixture exercises a specific parser behaviour; comments name the scenario.
class ParserEdgeTest < Minitest::Test
  include MPS

  ASSETS = File.expand_path("assets", __dir__)

  def parse(filename)
    path = File.join(ASSETS, filename)
    ec = Elements.constants.map { |k| Elements.const_get(k) }.select { |x| x.class == Class }
    Engines::Parser.parse_mps_file_to_elements_hash(path, ec)
  end

  def non_root(els)
    els.values.reject { |e| e.is_a?(Elements::MPS) }
  end

  # ── 20260301: empty bodies ───────────────────────────────────────────────────

  def test_empty_body_task_parses
    els = non_root(parse("20260301.1000000100.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) }
    refute_nil task
    assert task.body_str.strip.empty?, "empty-body task should have empty body_str"
  end

  def test_empty_body_note_parses
    els = non_root(parse("20260301.1000000100.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    refute_nil note
    assert note.body_str.strip.empty?
  end

  def test_empty_body_log_has_duration
    els = non_root(parse("20260301.1000000100.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    refute_nil log
    assert_equal 60, log.duration_minutes, "09:00–10:00 = 60 min even with empty body"
    assert_equal "1h", log.duration_str
  end

  def test_empty_body_reminder_has_at
    els = non_root(parse("20260301.1000000100.mps"))
    reminder = els.find { |e| e.is_a?(Elements::Reminder) }
    refute_nil reminder
    assert_equal "noon", reminder.parsed_args[:at]
  end

  def test_empty_body_file_total_element_count
    els = non_root(parse("20260301.1000000100.mps"))
    assert_equal 4, els.size
  end

  # ── 20260302: 4-level nesting ────────────────────────────────────────────────

  def test_four_level_nesting_total_elements
    els = non_root(parse("20260302.1000000101.mps"))
    # task at 4 levels, note at 4 levels, task at 3 levels, task at 2 levels, outer task, outer note
    assert_equal 4, els.count { |e| e.is_a?(Elements::Task) }
    assert_equal 2, els.count { |e| e.is_a?(Elements::Note) }
  end

  def test_four_level_nesting_deepest_task
    els = non_root(parse("20260302.1000000101.mps"))
    deep = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Four levels deep" }
    refute_nil deep
  end

  def test_four_level_nesting_ref_depth
    all = parse("20260302.1000000101.mps")
    deep_task_ref = all.find { |_, e| e.is_a?(Elements::Task) && e.body_str.strip == "Four levels deep" }&.first
    refute_nil deep_task_ref
    assert_equal 5, deep_task_ref.split(".").size, "4-level-deep task should have 5-segment ref (epoch + 4 depths)"
  end

  def test_four_level_top_level_task
    els = non_root(parse("20260302.1000000101.mps"))
    outer = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Top level outer" }
    refute_nil outer
  end

  # ── 20260303: many same-type elements ────────────────────────────────────────

  def test_many_tasks_all_parsed
    els = non_root(parse("20260303.1000000102.mps"))
    assert_equal 5, els.count { |e| e.is_a?(Elements::Task) }
  end

  def test_many_tasks_open_and_done_counts
    els = non_root(parse("20260303.1000000102.mps"))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    assert_equal 3, tasks.count(&:open?)
    assert_equal 2, tasks.count(&:done?)
  end

  def test_many_notes_all_parsed
    els = non_root(parse("20260303.1000000102.mps"))
    assert_equal 3, els.count { |e| e.is_a?(Elements::Note) }
  end

  def test_many_logs_all_parsed
    els = non_root(parse("20260303.1000000102.mps"))
    logs = els.select { |e| e.is_a?(Elements::Log) }
    assert_equal 2, logs.size
    timed = logs.find { |e| e.duration_minutes }
    assert_equal 60, timed.duration_minutes
  end

  # ── 20260304: hyphenated/underscored tags ────────────────────────────────────

  def test_hyphenated_tags_preserved
    els = non_root(parse("20260304.1000000103.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) }
    assert_includes task.tags, "mps-dev"
    assert_includes task.tags, "work_item"
    assert_includes task.tags, "v2"
  end

  def test_hyphenated_tags_in_note
    els = non_root(parse("20260304.1000000103.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    assert_includes note.tags, "project-alpha"
    assert_includes note.tags, "sprint_2"
  end

  def test_hyphenated_tag_in_log
    els = non_root(parse("20260304.1000000103.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_includes log.tags, "feature-123"
    assert_equal "2h30m", log.duration_str
  end

  def test_hyphenated_tag_in_reminder
    els = non_root(parse("20260304.1000000103.mps"))
    r = els.find { |e| e.is_a?(Elements::Reminder) }
    assert_includes r.tags, "daily-standup"
    assert_equal "3pm", r.parsed_args[:at]
  end

  # ── 20260306: unknowns interleaved with known elements ───────────────────────

  def test_unknowns_interleaved_known_count
    els = non_root(parse("20260306.1000000105.mps"))
    known = els.reject { |e| e.is_a?(Engines::Parser::Unknown) }
    assert_equal 3, known.size, "expect task + note + log as known elements"
  end

  def test_unknowns_interleaved_unknown_count
    els = non_root(parse("20260306.1000000105.mps"))
    unknowns = els.select { |e| e.is_a?(Engines::Parser::Unknown) }
    assert_equal 4, unknowns.size
  end

  def test_unknowns_interleaved_task_body_correct
    els = non_root(parse("20260306.1000000105.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) }
    assert_equal "Real task after unknown", task.body_str.strip
  end

  def test_unknowns_interleaved_note_body_correct
    els = non_root(parse("20260306.1000000105.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    assert_equal "Real note between unknowns", note.body_str.strip
  end

  def test_unknowns_have_ecn_set
    els = non_root(parse("20260306.1000000105.mps"))
    unknowns = els.select { |e| e.is_a?(Engines::Parser::Unknown) }
    ecns = unknowns.map(&:ecn).sort
    assert_includes ecns, "widget"
    assert_includes ecns, "gadget"
    assert_includes ecns, "sprocket"
    assert_includes ecns, "thingamajig"
  end

  # ── 20260307: unicode and special chars in body ──────────────────────────────

  def test_unicode_body_parses_without_crash
    assert parse("20260307.1000000106.mps")
  end

  def test_unicode_note_body_preserved
    els = non_root(parse("20260307.1000000106.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    assert_match(/日本語/, note.body_str)
    assert_match(/🎯/, note.body_str)
    assert_match(/مرحبا/, note.body_str)
  end

  def test_special_chars_in_body_no_extra_unknowns
    els = non_root(parse("20260307.1000000106.mps"))
    assert els.none? { |e| e.is_a?(Engines::Parser::Unknown) }
    assert_equal 3, els.size
  end

  def test_email_at_in_body_not_parsed_as_element
    els = non_root(parse("20260307.1000000106.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) }
    assert_match(/contact@example\.com/, task.body_str)
    assert_equal 1, els.count { |e| e.is_a?(Elements::Task) }
  end

  # ── 20260309: complex nested mps ────────────────────────────────────────────

  def test_complex_nested_tasks_total
    els = non_root(parse("20260309.1000000108.mps"))
    assert_equal 3, els.count { |e| e.is_a?(Elements::Task) }
  end

  def test_complex_nested_open_tasks
    els = non_root(parse("20260309.1000000108.mps"))
    open = els.select { |e| e.is_a?(Elements::Task) && e.open? }
    assert_equal 2, open.size
  end

  def test_complex_nested_log_duration
    els = non_root(parse("20260309.1000000108.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_equal 510, log.duration_minutes
    assert_equal "8h30m", log.duration_str
  end

  def test_complex_nested_sub_milestone_task
    els = non_root(parse("20260309.1000000108.mps"))
    sub = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Write API integration tests" }
    refute_nil sub
    assert_includes sub.tags, "backend"
  end

  # ── 20260310: epoch-less file ────────────────────────────────────────────────

  def test_epoch_less_file_parses
    els = non_root(parse("20260310.mps"))
    assert_equal 1, els.count { |e| e.is_a?(Elements::Task) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Note) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Log) }
  end

  def test_epoch_less_file_ref_format
    all = parse("20260310.mps")
    task_ref = all.find { |_, e| e.is_a?(Elements::Task) }&.first
    refute_nil task_ref
    parts = task_ref.split(".")
    assert_equal 2, parts.size, "epoch-less file: ref should be date.index (2 parts)"
    assert_equal "20260310", parts.first
  end

  def test_epoch_less_file_log_duration
    els = non_root(parse("20260310.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_equal 60, log.duration_minutes
  end

  # ── 20260311: whitespace in args ─────────────────────────────────────────────

  def test_whitespace_args_trimmed_to_correct_tag
    els = non_root(parse("20260311.1000000110.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("extra whitespace") }
    assert_equal %w[work], task.tags
    assert_equal "open", task.parsed_args[:status]
  end

  def test_whitespace_only_args_treated_as_no_args
    els = non_root(parse("20260311.1000000110.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    assert_equal [], note.tags
  end

  def test_whitespace_args_log_duration_correct
    els = non_root(parse("20260311.1000000110.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_equal 60, log.duration_minutes, "spaces around time values should not break parsing"
  end

  def test_whitespace_args_reversed_attr_tag_order
    els = non_root(parse("20260311.1000000110.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("reversed attr") }
    assert_equal "done", task.parsed_args[:status]
    assert_equal %w[work], task.tags
  end

  # ── 20260312: @ signs in body (no brace → not parsed as element) ─────────────

  def test_at_in_body_not_parsed_as_unknown
    els = non_root(parse("20260312.1000000111.mps"))
    assert els.none? { |e| e.is_a?(Engines::Parser::Unknown) },
           "@ followed by word without { should not be parsed as element"
  end

  def test_at_in_body_correct_element_count
    els = non_root(parse("20260312.1000000111.mps"))
    assert_equal 1, els.count { |e| e.is_a?(Elements::Note) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Task) }
    assert_equal 1, els.count { |e| e.is_a?(Elements::Log) }
  end

  def test_at_in_body_preserved_in_body_str
    els = non_root(parse("20260312.1000000111.mps"))
    note = els.find { |e| e.is_a?(Elements::Note) }
    assert_match(/@john\.doe/, note.body_str)
    assert_match(/@deprecated/, note.body_str)
  end

  def test_at_log_duration_correct_despite_at_in_body
    els = non_root(parse("20260312.1000000111.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_equal 90, log.duration_minutes
    assert_equal "1h30m", log.duration_str
  end

  # ── 20260313: 5-level nesting ────────────────────────────────────────────────

  def test_five_level_nesting_all_tasks
    els = non_root(parse("20260313.1000000112.mps"))
    tasks = els.select { |e| e.is_a?(Elements::Task) }
    # five-deep, four-deep, three-deep, two-deep, root-one, root-two = 6
    assert_equal 6, tasks.size
  end

  def test_five_level_nesting_deepest_task
    els = non_root(parse("20260313.1000000112.mps"))
    five_deep = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Five levels deep" }
    refute_nil five_deep
  end

  def test_five_level_nesting_deepest_ref_depth
    all = parse("20260313.1000000112.mps")
    ref = all.find { |_, e| e.is_a?(Elements::Task) && e.body_str.strip == "Five levels deep" }&.first
    refute_nil ref
    assert_equal 6, ref.split(".").size, "5-level-deep task: epoch + 5 depth segments = 6 parts"
  end

  def test_five_level_nesting_root_tasks
    els = non_root(parse("20260313.1000000112.mps"))
    root_done = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Root task one" }
    root_open = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Root task two" }
    assert root_done&.done?
    assert root_open&.open?
  end

  # ── 20260316: mixed types edge cases ────────────────────────────────────────

  def test_task_with_only_status_attr_no_tags
    els = non_root(parse("20260316.1000000202.mps"))
    task = els.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("only status attr") }
    assert_equal [], task.tags
    assert_equal "done", task.parsed_args[:status]
  end

  def test_bare_task_no_args_at_all
    els = non_root(parse("20260316.1000000202.mps"))
    bare = els.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Bare task — no args at all" }
    refute_nil bare
    assert_equal [], bare.tags
    assert_equal "open", bare.parsed_args[:status]
  end

  def test_short_log_30_minutes
    els = non_root(parse("20260316.1000000202.mps"))
    log = els.find { |e| e.is_a?(Elements::Log) }
    assert_equal 30, log.duration_minutes
    assert_equal "0h30m", log.duration_str
  end

  # ── 20260501: task-in-task (the nested_test.mps pattern) ────────────────────

  def test_task_in_task_total_elements
    all = parse("20260501.1800000001.mps")
    els = non_root(all)
    # outer task + 3 child tasks + 3 child notes = 7 (root @mps excluded by non_root)
    assert_equal 7, els.size, "expected 7 non-root elements, got #{els.size}"
  end

  def test_task_in_task_task_count
    els = non_root(parse("20260501.1800000001.mps"))
    assert_equal 4, els.count { |e| e.is_a?(Elements::Task) }, "1 outer + 3 nested tasks"
  end

  def test_task_in_task_note_count
    els = non_root(parse("20260501.1800000001.mps"))
    assert_equal 3, els.count { |e| e.is_a?(Elements::Note) }, "3 notes nested inside dev task"
  end

  def test_task_in_task_outer_task_status_open
    all = parse("20260501.1800000001.mps")
    outer = all.values.find { |e| e.is_a?(Elements::Task) && e.raw_args == "status: open" }
    refute_nil outer, "outer task with status: open not found"
    assert outer.open?
  end

  def test_task_in_task_inner_tasks_default_open
    all = parse("20260501.1800000001.mps")
    inner_tasks = all.values.select { |e| e.is_a?(Elements::Task) && e.raw_args == "" }
    assert_equal 3, inner_tasks.size, "3 inner tasks with no args"
    assert inner_tasks.all?(&:open?), "all no-args tasks default to open"
  end

  def test_task_in_task_ref_depths
    all = parse("20260501.1800000001.mps")
    # outer task: epoch.1 → 2 segments
    outer_ref = all.find { |_, e| e.is_a?(Elements::Task) && e.raw_args == "status: open" }&.first
    assert_equal 2, outer_ref.split(".").size, "outer task ref has 2 segments (epoch.1)"
    # child tasks: epoch.1.X → 3 segments
    child_task_refs = all.select { |_, e| e.is_a?(Elements::Task) && e.raw_args == "" }.keys
    assert child_task_refs.all? { |r| r.split(".").size == 3 },
           "all 3 no-args child tasks have 3-segment refs"
    # notes: epoch.1.3.X → 4 segments
    note_refs = all.select { |_, e| e.is_a?(Elements::Note) }.keys
    assert note_refs.all? { |r| r.split(".").size == 4 },
           "all notes have 4-segment refs (epoch.1.3.X)"
  end

  def test_task_in_task_leaf_bodies_clean
    all = parse("20260501.1800000001.mps")
    bugs     = all.values.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("bugs") }
    meetings = all.values.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("meetings") }
    refute_nil bugs,     "bugs task found"
    refute_nil meetings, "meetings task found"
    assert_equal "Several bugs to be fixed",        bugs.body_str.strip
    assert_equal "Several meetings to be attended", meetings.body_str.strip
  end

  def test_task_in_task_outer_body_contains_child_syntax
    all = parse("20260501.1800000001.mps")
    outer = all.values.find { |e| e.is_a?(Elements::Task) && e.raw_args == "status: open" }
    assert_match(/@task\{/, outer.body_str, "outer task body includes literal @task{ syntax")
    assert_match(/These items to be done by monday/, outer.body_str, "own text present")
  end

  def test_task_in_task_dev_task_body_contains_note_syntax
    all = parse("20260501.1800000001.mps")
    dev_task = all.values.find { |e| e.is_a?(Elements::Task) && e.body_str.include?("dev works") }
    refute_nil dev_task
    assert_match(/@note\{/, dev_task.body_str, "dev task body includes @note{ syntax")
    assert_match(/Several dev works to be done/, dev_task.body_str)
  end

  def test_task_in_task_note_bodies
    all = parse("20260501.1800000001.mps")
    notes = all.values.select { |e| e.is_a?(Elements::Note) }
    bodies = notes.map { |n| n.body_str.strip }.sort
    assert_includes bodies, "Check for items not done"
    assert_includes bodies, "Check for peoples support"
    assert_includes bodies, "Say No to not aligned with my goal"
  end

  # ── 20260502: tagged @mps and note-in-task ───────────────────────────────────

  def test_tagged_mps_total_elements
    els = non_root(parse("20260502.1800000002.mps"))
    # sprint mps excluded by non_root; remaining: task+note+task in sprint + done-task + note-in-task + bare-note
    assert_equal 6, els.size, "6 non-mps elements"
  end

  def test_tagged_mps_block_has_two_tags
    all = parse("20260502.1800000002.mps")
    sprint_mps = all.values.find { |e| e.is_a?(Elements::MPS) && e.raw_args == "sprint-42, current" }
    refute_nil sprint_mps, "sprint mps block found"
    assert_includes sprint_mps.tags, "sprint-42"
    assert_includes sprint_mps.tags, "current"
  end

  def test_tagged_mps_note_inside_has_review_tag
    all = parse("20260502.1800000002.mps")
    note = all.values.find { |e| e.is_a?(Elements::Note) && e.body_str.include?("Sprint review") }
    refute_nil note
    assert_includes note.tags, "review"
  end

  def test_tagged_mps_done_task_inside_sprint
    all = parse("20260502.1800000002.mps")
    done = all.values.find { |e| e.is_a?(Elements::Task) && e.done? && e.tags.include?("backend") }
    refute_nil done, "done backend task inside sprint mps found"
    assert_equal "Completed backend task", done.body_str.strip
  end

  def test_note_in_task_ref_depth
    all = parse("20260502.1800000002.mps")
    note_in_task = all.values.find { |e| e.is_a?(Elements::Note) && e.body_str.include?("Note inside done task") }
    refute_nil note_in_task
    ref = all.find { |_, e| e.is_a?(Elements::Note) && e.body_str.include?("Note inside done task") }&.first
    assert_equal 3, ref.split(".").size, "note inside task has 3-segment ref (epoch.2.1)"
  end

  def test_bare_top_level_note_ref_depth
    all = parse("20260502.1800000002.mps")
    ref = all.find { |_, e| e.is_a?(Elements::Note) && e.body_str.strip == "Bare top-level note" }&.first
    refute_nil ref
    assert_equal 2, ref.split(".").size, "bare note at top level has 2-segment ref (epoch.N)"
  end

  def test_tagged_mps_task_and_note_counts
    all = parse("20260502.1800000002.mps")
    assert_equal 3, all.values.count { |e| e.is_a?(Elements::Task) }, "3 tasks total"
    assert_equal 3, all.values.count { |e| e.is_a?(Elements::Note) }, "3 notes total"
    assert_equal 2, all.values.count { |e| e.is_a?(Elements::MPS) },  "2 mps elements (root + sprint)"
  end
end
