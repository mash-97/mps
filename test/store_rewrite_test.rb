# frozen_string_literal: true

require_relative "test_helper"

class StoreRewriteTest < Minitest::Test
  include MPS

  STORAGE_DIR = "/fake/mps"
  DATE        = Date.new(2026, 1, 4)
  DATE_STR    = "20260104"
  EPOCH       = "1000000004"
  FAKE_FILE   = "#{STORAGE_DIR}/#{DATE_STR}.#{EPOCH}.mps"

  CONTENT = <<~MPS
    @task[work, status: open]{
      Fix the login bug
    }

    @note{
      Check the token expiry edge case
    }

    @task[backend, status: open]{
      Write the migration script
    }
  MPS

  def store
    MPS::Store.new(STORAGE_DIR)
  end

  def setup_fake_file(content = CONTENT)
    FileUtils.mkdir_p(STORAGE_DIR)
    File.write(FAKE_FILE, content)
  end

  # ── rewrite_element via epoch ref ──────────────────────────────────────────

  def test_rewrite_changes_status
    FakeFS.with_fresh do
      setup_fake_file
      ref = "#{DATE_STR}.1"
      result = store.rewrite_element(ref, { status: "done" })
      assert result, "rewrite_element should return true"
      new_content = File.read(FAKE_FILE)
      # Rewrite puts attr pairs first, then tags — consistent with append format
      assert_match(/@task\[status: done, work\]/, new_content)
    end
  end

  def test_rewrite_preserves_tags
    FakeFS.with_fresh do
      setup_fake_file
      store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      parsed = store.parse_date(DATE)
      task = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Fix the login bug" }
      assert_equal %w[work], task.tags
      assert_equal "done", task.parsed_args[:status]
    end
  end

  def test_rewrite_does_not_affect_other_elements
    FakeFS.with_fresh do
      setup_fake_file
      store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      parsed = store.parse_date(DATE)
      other_task = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Write the migration script" }
      assert_equal "open", other_task.parsed_args[:status]
    end
  end

  def test_rewrite_returns_false_for_unknown_ref
    FakeFS.with_fresh do
      setup_fake_file
      result = store.rewrite_element("#{DATE_STR}.99", { status: "done" })
      refute result
    end
  end

  def test_rewrite_returns_false_when_no_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      result = store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      refute result
    end
  end

  # ── rewrite_element via human ref ──────────────────────────────────────────

  def test_rewrite_via_human_ref
    FakeFS.with_fresh do
      setup_fake_file
      result = store.rewrite_element("task-1", { status: "done" }, date: DATE)
      assert result
      parsed = store.parse_date(DATE)
      task = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Fix the login bug" }
      assert_equal "done", task.parsed_args[:status]
    end
  end

  def test_rewrite_second_task_via_human_ref
    FakeFS.with_fresh do
      setup_fake_file
      result = store.rewrite_element("task-2", { status: "done" }, date: DATE)
      assert result
      parsed = store.parse_date(DATE)
      task = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Write the migration script" }
      assert_equal "done", task.parsed_args[:status]
    end
  end

  # ── round-trip: append → rewrite → re-parse ────────────────────────────────

  def test_round_trip_append_rewrite_reparse
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      store.append(type: "task", body: "round-trip task", tags: %w[test], date: DATE)
      elements = store.parse_date(DATE)
      task_ref = elements.find { |_, e| e.is_a?(Elements::Task) }&.first
      refute_nil task_ref

      result = store.rewrite_element(task_ref, { status: "done" })
      assert result

      re_parsed = store.parse_date(DATE)
      task_again = re_parsed[task_ref]
      assert_equal "done", task_again.parsed_args[:status]
      assert_equal "round-trip task", task_again.body_str.strip
      assert_equal %w[test], task_again.tags
    end
  end

  # ── rewrite element without brackets (bare @type{ form) ────────────────────

  def test_rewrite_no_bracket_element
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_FILE, "@task{\n  bare task\n}\n")
      result = store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      assert result
      parsed = store.parse_date(DATE)
      task = parsed.values.find { |e| e.is_a?(Elements::Task) }
      assert_equal "done", task.parsed_args[:status]
    end
  end

  # ── rewrite element with empty brackets (@type[]{ form) ──────────────────────

  def test_rewrite_empty_bracket_element
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_FILE, "@task[]{\n  empty bracket task\n}\n")
      result = store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      assert result, "rewrite_element should succeed for @task[]{} form"
      parsed = store.parse_date(DATE)
      task = parsed.values.find { |e| e.is_a?(Elements::Task) }
      assert_equal "done", task.parsed_args[:status]
    end
  end

  def test_rewrite_empty_bracket_preserves_other_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      content = "@task[]{\n  first\n}\n@task[work]{\n  second\n}\n"
      File.write(FAKE_FILE, content)
      store.rewrite_element("#{DATE_STR}.1", { status: "done" })
      parsed = store.parse_date(DATE)
      first  = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "first" }
      second = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "second" }
      assert_equal "done", first.parsed_args[:status]
      # second task had no explicit status — keeps default "open" (unchanged)
      refute_equal "done", second.parsed_args[:status]
    end
  end
end
