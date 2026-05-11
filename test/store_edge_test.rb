# frozen_string_literal: true

require_relative "test_helper"

# Edge-case tests for Store — multiple files per day, duplicate-args rewrite
# collision, and search across interleaved unknown elements.
class StoreEdgeTest < Minitest::Test
  include MPS

  STORAGE_DIR = "/fake/mps"
  ASSETS      = File.expand_path("assets", __dir__)

  # Fixture file content is read before entering FakeFS (FakeFS blocks real fs).
  CONTENT_200 = File.read(File.join(File.expand_path("assets", __dir__), "20260315.1000000200.mps"))
  CONTENT_201 = File.read(File.join(File.expand_path("assets", __dir__), "20260315.1000000201.mps"))
  CONTENT_107 = File.read(File.join(File.expand_path("assets", __dir__), "20260308.1000000107.mps"))
  CONTENT_105 = File.read(File.join(File.expand_path("assets", __dir__), "20260306.1000000105.mps"))

  DATE_315 = Date.new(2026, 3, 15)
  DATE_308 = Date.new(2026, 3, 8)
  DATE_306 = Date.new(2026, 3, 6)

  def store
    MPS::Store.new(STORAGE_DIR)
  end

  # ── Multiple files per day ──────────────────────────────────────────────────

  def test_find_files_returns_both_files_for_same_day
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      result = store.find_files(DATE_315)
      assert_equal 2, result.size
    end
  end

  def test_find_file_returns_first_sorted_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      result = store.find_file(DATE_315)
      assert_equal File.join(STORAGE_DIR, "20260315.1000000200.mps"), result
    end
  end

  def test_parse_date_returns_only_first_file_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      elements = store.parse_date(DATE_315)
      tasks = elements.values.select { |e| e.is_a?(Elements::Task) }
      # First file has 1 task ("First file task — morning work")
      assert_equal 1, tasks.size
      assert_match(/morning work/, tasks.first.body_str)
    end
  end

  def test_search_finds_elements_from_both_files_same_day
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      # "task" appears in body of elements in both files
      results = store.search("file task")
      assert results.size >= 2, "search should find tasks from both files (got #{results.size})"
    end
  end

  def test_search_second_file_log_found
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      results = store.search("Afternoon session")
      assert_equal 1, results.size
      assert_instance_of Elements::Log, results.first[:element]
    end
  end

  # ── Duplicate raw_args rewrite collision ────────────────────────────────────
  # Bug: before fix, rewriting "task-2" when task-1 and task-2 share identical
  # raw_args caused task-1 to be rewritten instead of task-2.

  def test_rewrite_does_not_confuse_identical_raw_args
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260308.1000000107.mps"), CONTENT_107)
      result = store.rewrite_element("task-2", { status: "done" }, date: DATE_308)
      assert result

      parsed = store.parse_date(DATE_308)
      first  = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "First open work task" }
      second = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Second open work task" }
      assert_equal "open", first.parsed_args[:status],  "task-1 (first) must stay open"
      assert_equal "done", second.parsed_args[:status], "task-2 (second) must become done"
    end
  end

  def test_rewrite_fourth_of_five_tasks_duplicate_args
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260308.1000000107.mps"), CONTENT_107)
      # task-3 and task-4 share "backend, status: done"
      # Rewrite task-4 to status: open — should leave task-3 unchanged
      result = store.rewrite_element("task-4", { status: "open" }, date: DATE_308)
      assert result

      parsed = store.parse_date(DATE_308)
      third  = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "First done backend task" }
      fourth = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Second done backend task" }
      assert_equal "done", third.parsed_args[:status],  "task-3 must stay done"
      assert_equal "open", fourth.parsed_args[:status], "task-4 must become open"
    end
  end

  def test_rewrite_first_of_duplicate_pair_is_correct
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260308.1000000107.mps"), CONTENT_107)
      result = store.rewrite_element("task-1", { status: "done" }, date: DATE_308)
      assert result

      parsed = store.parse_date(DATE_308)
      first  = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "First open work task" }
      second = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "Second open work task" }
      assert_equal "done", first.parsed_args[:status],  "task-1 must become done"
      assert_equal "open", second.parsed_args[:status], "task-2 must stay open"
    end
  end

  def test_rewrite_inline_duplicate_args_via_fakefs
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      path = File.join(STORAGE_DIR, "20260308.1000000107.mps")
      content = "@task[work, status: open]{\n  alpha\n}\n@task[work, status: open]{\n  beta\n}\n@task[work, status: open]{\n  gamma\n}\n"
      File.write(path, content)

      result = store.rewrite_element("task-3", { status: "done" }, date: DATE_308)
      assert result

      parsed = store.parse_date(DATE_308)
      alpha = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "alpha" }
      beta  = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "beta" }
      gamma = parsed.values.find { |e| e.is_a?(Elements::Task) && e.body_str.strip == "gamma" }
      assert_equal "open", alpha.parsed_args[:status], "alpha (task-1) must stay open"
      assert_equal "open", beta.parsed_args[:status],  "beta (task-2) must stay open"
      assert_equal "done", gamma.parsed_args[:status], "gamma (task-3) must become done"
    end
  end

  # ── Search across unknowns ──────────────────────────────────────────────────

  def test_search_finds_known_elements_in_file_with_unknowns
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260306.1000000105.mps"), CONTENT_105)
      results = store.search("Real task")
      assert_equal 1, results.size
      assert_instance_of Elements::Task, results.first[:element]
    end
  end

  def test_search_does_not_return_unknown_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260306.1000000105.mps"), CONTENT_105)
      results = store.search(nil)
      assert results.none? { |r| r[:element].is_a?(Engines::Parser::Unknown) }
    end
  end

  def test_search_nil_query_returns_all_known_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260306.1000000105.mps"), CONTENT_105)
      results = store.search(nil)
      # 1 task + 1 note + 1 log = 3 known elements (4 unknowns excluded)
      assert_equal 3, results.size
    end
  end

  # ── all_file_dates helpers ───────────────────────────────────────────────────

  def test_all_file_dates_deduplicates_same_day
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(File.join(STORAGE_DIR, "20260315.1000000200.mps"), CONTENT_200)
      File.write(File.join(STORAGE_DIR, "20260315.1000000201.mps"), CONTENT_201)
      dates = store.all_files
                   .map { |f| File.basename(f).slice(0, 8) }
                   .uniq
      assert_equal ["20260315"], dates
    end
  end
end
