# frozen_string_literal: true

require_relative 'test_helper'

class StoreTest < Minitest::Test
  include MPS

  STORAGE_DIR = "/fake/mps"
  DATE        = Date.new(2026, 1, 1)
  DATE_STR    = "20260101"
  EPOCH       = "1234567890"
  FAKE_FILE   = "#{DATE_STR}.#{EPOCH}.mps"
  FAKE_PATH   = "#{STORAGE_DIR}/#{FAKE_FILE}"

  def store
    ::MPS::Store.new(STORAGE_DIR)
  end

  # ── find_file ──────────────────────────────────────────────────────────────

  def test_find_file_returns_nil_when_absent
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      assert_nil store.find_file(DATE)
    end
  end

  def test_find_file_returns_path_when_present
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      FileUtils.touch(FAKE_PATH)
      assert_equal FAKE_PATH, store.find_file(DATE)
    end
  end

  def test_find_files_returns_all_for_date
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      path1 = "#{STORAGE_DIR}/#{DATE_STR}.1000000001.mps"
      path2 = "#{STORAGE_DIR}/#{DATE_STR}.1000000002.mps"
      FileUtils.touch(path1)
      FileUtils.touch(path2)
      result = store.find_files(DATE)
      assert_equal 2, result.size
      assert_includes result, path1
      assert_includes result, path2
    end
  end

  # ── find_or_create_path ────────────────────────────────────────────────────

  def test_find_or_create_path_generates_new_name_when_absent
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      path = store.find_or_create_path(DATE)
      assert_match(/#{DATE_STR}\.\d{10,}\.mps$/, path)
      refute File.exist?(path), "should not create the file, only return the path"
    end
  end

  def test_find_or_create_path_returns_existing
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      FileUtils.touch(FAKE_PATH)
      assert_equal FAKE_PATH, store.find_or_create_path(DATE)
    end
  end

  # ── parse_date ─────────────────────────────────────────────────────────────

  def test_parse_date_returns_empty_when_no_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      assert_equal({}, store.parse_date(DATE))
    end
  end

  def test_parse_date_returns_mps_wrapper_for_empty_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "")
      result = store.parse_date(DATE)
      assert_instance_of Hash, result
      mps_els = result.values.select { |e| e.is_a?(Elements::MPS) }
      assert_equal 1, mps_els.size
    end
  end

  def test_parse_date_parses_task
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "@task[work]{\n  Ship it\n}\n")
      result = store.parse_date(DATE)
      tasks  = result.values.select { |e| e.is_a?(Elements::Task) }
      assert_equal 1, tasks.size
      assert_equal "Ship it", tasks.first.body_str.strip
      assert_equal %w[work], tasks.first.tags
    end
  end

  # ── append ─────────────────────────────────────────────────────────────────

  def test_append_creates_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      path = store.append(type: "task", body: "do thing", tags: %w[work], date: DATE)
      assert File.exist?(path)
    end
  end

  def test_append_content_is_parseable
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      store.append(type: "task", body: "do thing", tags: %w[work release], date: DATE)
      result = store.parse_date(DATE)
      tasks  = result.values.select { |e| e.is_a?(Elements::Task) }
      assert_equal 1, tasks.size
      assert_equal "do thing", tasks.first.body_str.strip
      assert_equal %w[work release], tasks.first.tags
    end
  end

  def test_append_with_attrs
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      store.append(type: "log", body: "deep work",
                   attrs: { start: "09:00", end: "12:30" }, date: DATE)
      result = store.parse_date(DATE)
      logs   = result.values.select { |e| e.is_a?(Elements::Log) }
      assert_equal 1, logs.size
      assert_equal "3h30m", logs.first.duration_str
    end
  end

  def test_append_multiple_creates_distinct_elements
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      store.append(type: "task", body: "first",  date: DATE)
      store.append(type: "note", body: "second", date: DATE)
      result = store.parse_date(DATE)
      assert_equal 1, result.values.count { |e| e.is_a?(Elements::Task) }
      assert_equal 1, result.values.count { |e| e.is_a?(Elements::Note) }
    end
  end

  # ── all_files / files_since ────────────────────────────────────────────────

  def test_all_files_returns_sorted_list
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      p1 = "#{STORAGE_DIR}/20260101.1000000001.mps"
      p2 = "#{STORAGE_DIR}/20260102.1000000002.mps"
      FileUtils.touch(p2)
      FileUtils.touch(p1)
      assert_equal [p1, p2], store.all_files
    end
  end

  def test_files_since_filters_by_date
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      old  = "#{STORAGE_DIR}/20260101.1000000001.mps"
      new1 = "#{STORAGE_DIR}/20260110.1000000002.mps"
      new2 = "#{STORAGE_DIR}/20260115.1000000003.mps"
      [old, new1, new2].each { |p| FileUtils.touch(p) }
      result = store.files_since(Date.new(2026, 1, 10))
      assert_includes result, new1
      assert_includes result, new2
      refute_includes result, old
    end
  end

  # ── search ─────────────────────────────────────────────────────────────────

  def test_search_finds_by_query
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "@task[]{\n  deploy to production\n}\n@note[]{\n  unrelated\n}\n")
      results = store.search("deploy")
      assert_equal 1, results.size
      assert_equal "deploy to production", results.first[:element].body_str.strip
    end
  end

  def test_search_type_filter
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "@task[]{\n  deploy\n}\n@note[]{\n  deploy note\n}\n")
      results = store.search("deploy", type_filter: "task")
      assert_equal 1, results.size
      assert_instance_of Elements::Task, results.first[:element]
    end
  end

  def test_search_tag_filter
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "@task[work]{\n  deploy\n}\n@task[personal]{\n  deploy too\n}\n")
      results = store.search("deploy", tag_filter: "work")
      assert_equal 1, results.size
      assert_includes results.first[:element].tags, "work"
    end
  end

  def test_search_since_date_excludes_old_files
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      old_path = "#{STORAGE_DIR}/20260101.1000000001.mps"
      new_path = "#{STORAGE_DIR}/20260115.1000000002.mps"
      File.write(old_path, "@task[]{\n  old task\n}\n")
      File.write(new_path, "@task[]{\n  new task\n}\n")
      results = store.search("task", since_date: Date.new(2026, 1, 10))
      assert_equal 1, results.size
      assert_equal "new task", results.first[:element].body_str.strip
    end
  end

  def test_search_returns_date_str
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "@task[]{\n  thing\n}\n")
      results = store.search("thing")
      assert_equal DATE_STR, results.first[:date_str]
    end
  end

  # ── epoch-less filenames (e.g. 20241103.mps) ──────────────────────────────

  def test_all_files_includes_epoch_less_names
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      epoched  = "#{STORAGE_DIR}/20260101.1000000001.mps"
      no_epoch = "#{STORAGE_DIR}/20260102.mps"
      FileUtils.touch(epoched)
      FileUtils.touch(no_epoch)
      result = store.all_files
      assert_includes result, epoched
      assert_includes result, no_epoch
    end
  end

  def test_find_files_matches_epoch_less_name
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      path = "#{STORAGE_DIR}/20260101.mps"
      FileUtils.touch(path)
      result = store.find_files(DATE)
      assert_equal [path], result
    end
  end

  # ── non-date filenames are ignored ────────────────────────────────────────

  def test_all_files_ignores_non_date_names
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      valid    = "#{STORAGE_DIR}/20260101.1000000001.mps"
      prose    = "#{STORAGE_DIR}/such_a_weird_feeling.mps"
      FileUtils.touch(valid)
      FileUtils.touch(prose)
      result = store.all_files
      assert_includes result, valid
      refute_includes result, prose
    end
  end

  # ── empty and plain-text files parse without crashing ─────────────────────

  def test_parse_date_empty_file_returns_root_wrapper
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "")
      result = store.parse_date(DATE)
      assert_instance_of Hash, result
      assert result.values.any? { |e| e.is_a?(Elements::MPS) }
      assert result.values.none? { |e| e.is_a?(Elements::Task) }
    end
  end

  def test_parse_date_plain_text_file_returns_root_wrapper
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_PATH, "this is just plain text, no elements\n")
      result = store.parse_date(DATE)
      assert_instance_of Hash, result
      assert result.values.any? { |e| e.is_a?(Elements::MPS) }
      assert result.values.none? { |e| e.is_a?(Elements::Task) }
    end
  end
end
