# frozen_string_literal: true

require_relative "test_helper"

# Integration-level tests: parse real fixture files and exercise Query, RefResolver,
# Store, and the tags/stats aggregation logic against story-rich content.
class IntegrationTest < Minitest::Test
  include MPS

  ASSETS_DIR   = File.expand_path("assets", __dir__)
  SPRINT_FILE  = "20260201.1000000010.mps"   # sprint planning day
  RUST_FILE    = "20260215.1000000020.mps"   # learning + habits day
  RELEASE_FILE = "20260220.1000000030.mps"   # release day

  def element_classes
    Elements.constants
      .map    { |k| Elements.const_get(k) }
      .select { |x| x.class == Class }
  end

  def parse(filename)
    Engines::Parser.parse_mps_file_to_elements_hash(
      File.join(ASSETS_DIR, filename), element_classes
    )
  end

  def non_root(elements)
    elements.reject { |_, e| e.is_a?(Elements::MPS) }
  end

  # ── Unknown element robustness ─────────────────────────────────────────────

  def test_ref_resolver_skips_unknown_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p("/fake")
      File.write("/fake/20260101.1000000001.mps", "@custom_type{ body }\n@task{ real task }")
      els = Engines::Parser.parse_mps_file_to_elements_hash("/fake/20260101.1000000001.mps", element_classes)
      resolver = RefResolver.new(els)
      # Unknown element should be silently skipped, not crash
      task_ref = els.find { |_, e| e.is_a?(Elements::Task) }&.first
      refute_nil resolver.to_human(task_ref), "task should still get a human ref"
    end
  end

  def test_query_excludes_unknown_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p("/fake")
      File.write("/fake/20260101.1000000001.mps", "@custom_type{ body }\n@task{ real task }")
      els = Engines::Parser.parse_mps_file_to_elements_hash("/fake/20260101.1000000001.mps", element_classes)
      result = Query.new.apply(els)
      refute result.values.any? { |e| e.is_a?(Engines::Parser::Unknown) }
      assert result.values.any? { |e| e.is_a?(Elements::Task) }
    end
  end

  # ── Sprint planning fixture ────────────────────────────────────────────────

  def test_sprint_tasks_count
    els  = non_root(parse(SPRINT_FILE))
    tasks = els.values.select { |e| e.is_a?(Elements::Task) }
    assert_equal 4, tasks.size
  end

  def test_sprint_open_tasks
    els   = non_root(parse(SPRINT_FILE))
    open  = els.values.select { |e| e.is_a?(Elements::Task) && e.open? }
    assert_equal 3, open.size
  end

  def test_sprint_done_tasks
    els  = non_root(parse(SPRINT_FILE))
    done = els.values.select { |e| e.is_a?(Elements::Task) && e.done? }
    assert_equal 1, done.size
    assert_equal "Set up the PostgreSQL schema", done.first.body_str.strip
  end

  def test_sprint_log_duration
    els  = non_root(parse(SPRINT_FILE))
    logs = els.values.select { |e| e.is_a?(Elements::Log) }
    assert_equal 1, logs.size
    assert_equal 210, logs.first.duration_minutes  # 3h30m
  end

  def test_sprint_reminder_at
    els       = non_root(parse(SPRINT_FILE))
    reminders = els.values.select { |e| e.is_a?(Elements::Reminder) }
    assert_equal 1, reminders.size
    assert_equal "3pm", reminders.first.parsed_args[:at]
  end

  def test_sprint_nested_tasks_inside_mps
    els      = parse(SPRINT_FILE)
    all_vals = els.values
    nested_tasks = all_vals.select { |e| e.is_a?(Elements::Task) }
                           .select { |e| e.tags.include?("backend") || e.tags.include?("frontend") }
    assert nested_tasks.size >= 3
  end

  def test_sprint_query_filter_by_tag
    els    = parse(SPRINT_FILE)
    result = Query.new(tag: "backend").apply(els)
    assert result.values.all? { |e| e.tags.include?("backend") }
    assert result.size >= 1
  end

  def test_sprint_query_filter_by_status
    els    = parse(SPRINT_FILE)
    result = Query.new(status: "done").apply(els)
    assert result.values.all? { |e| e.is_a?(Elements::Task) && e.done? }
  end

  # ── Rust/learning fixture ──────────────────────────────────────────────────

  def test_rust_done_reading_tasks
    els  = non_root(parse(RUST_FILE))
    done = els.values.select { |e| e.is_a?(Elements::Task) && e.done? && e.tags.include?("reading") }
    assert_equal 2, done.size
  end

  def test_rust_open_reading_task
    els   = non_root(parse(RUST_FILE))
    open  = els.values.select { |e| e.is_a?(Elements::Task) && e.open? && e.tags.include?("reading") }
    assert_equal 1, open.size
    assert_match(/Rustlings/, open.first.body_str)
  end

  def test_rust_nested_habit_tasks
    els          = non_root(parse(RUST_FILE))
    habit_tasks  = els.values.select { |e| e.is_a?(Elements::Task) && e.tags.include?("habits") }
    assert_equal 3, habit_tasks.size
    done_habits  = habit_tasks.select(&:done?)
    assert_equal 2, done_habits.size
  end

  def test_rust_log_duration
    els  = non_root(parse(RUST_FILE))
    logs = els.values.select { |e| e.is_a?(Elements::Log) }
    assert_equal 1, logs.size
    assert_equal 90, logs.first.duration_minutes  # 1h30m
  end

  def test_rust_ref_resolver_human_refs
    els      = parse(RUST_FILE)
    resolver = RefResolver.new(els)
    tasks    = els.select { |_, e| e.is_a?(Elements::Task) }
    tasks.each_key do |epoch_ref|
      human = resolver.to_human(epoch_ref)
      assert human, "every task should have a human ref (epoch #{epoch_ref})"
    end
  end

  # ── Release fixture ────────────────────────────────────────────────────────

  def test_release_done_tasks
    els  = non_root(parse(RELEASE_FILE))
    done = els.values.select { |e| e.is_a?(Elements::Task) && e.done? }
    assert_equal 2, done.size
  end

  def test_release_total_log_time
    els      = non_root(parse(RELEASE_FILE))
    logs     = els.values.select { |e| e.is_a?(Elements::Log) }
    total    = logs.sum { |e| e.duration_minutes || 0 }
    assert_equal 360, total  # 4h + 2h
  end

  def test_release_retro_nested_notes
    els   = parse(RELEASE_FILE)
    notes = els.values.select { |e| e.is_a?(Elements::Note) }
    assert notes.size >= 3
  end

  def test_release_retrospective_open_task
    els   = non_root(parse(RELEASE_FILE))
    tasks = els.values.select { |e| e.is_a?(Elements::Task) && e.open? }
    plan_task = tasks.find { |e| e.body_str.include?("v1.1") }
    refute_nil plan_task
  end

  def test_release_tags
    els    = non_root(parse(RELEASE_FILE))
    all_tags = els.values.flat_map(&:tags).uniq.sort
    assert_includes all_tags, "work"
    assert_includes all_tags, "release"
  end

  # ── Cross-fixture: multi-date tag aggregation ──────────────────────────────

  # Read real fixture content before entering FakeFS (FakeFS blocks real fs access).
  FIXTURE_CONTENTS = [SPRINT_FILE, RUST_FILE, RELEASE_FILE]
    .map { |f| [f, File.read(File.join(File.expand_path("assets", __dir__), f))] }.to_h

  def with_story_store
    FakeFS.with_fresh do
      storage = "/fake/storage"
      FileUtils.mkdir_p(storage)
      FIXTURE_CONTENTS.each do |filename, content|
        File.write(File.join(storage, filename), content)
      end
      yield Store.new(storage)
    end
  end

  def test_tag_counts_across_fixtures
    with_story_store do |s|
      all_tags = Hash.new(0)
      s.all_files.each do |file|
        s.parse_date(Date.strptime(File.basename(file)[0, 8], "%Y%m%d"))
         .values
         .reject { |e| e.is_a?(Elements::MPS) || e.is_a?(Engines::Parser::Unknown) }
         .each { |e| e.tags.each { |t| all_tags[t] += 1 } }
      end
      assert all_tags["work"] >= 3,    "work tag appears across multiple files"
      assert all_tags["reading"] >= 3, "reading tag from rust day"
      assert all_tags["release"] >= 2, "release tag from release day"
    end
  end

  def test_store_search_across_story_files
    with_story_store do |s|
      results = s.search("authentication")
      assert results.size >= 1
      assert results.none? { |r| r[:element].is_a?(Engines::Parser::Unknown) }
    end
  end

  def test_store_search_type_filter
    with_story_store do |s|
      results = s.search(nil, type_filter: "log")
      assert results.all? { |r| r[:element].is_a?(Elements::Log) }
    end
  end
end
