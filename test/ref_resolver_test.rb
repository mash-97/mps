# frozen_string_literal: true

require_relative "test_helper"

class RefResolverTest < Minitest::Test
  include MPS

  STORAGE_DIR = "/fake/mps"
  DATE        = Date.new(2026, 1, 1)
  DATE_INT    = 20260101
  FAKE_FILE   = "#{STORAGE_DIR}/20260101.1000000001.mps"

  def parse_file(content)
    FakeFS.with_fresh do
      FileUtils.mkdir_p(STORAGE_DIR)
      File.write(FAKE_FILE, content)
      Engines::Parser.parse_mps_file_to_elements_hash(FAKE_FILE, element_classes)
    end
  end

  def element_classes
    Elements.constants.map { |k| Elements.const_get(k) }.select { |x| x.class == Class }
  end

  def resolver_for(content)
    RefResolver.new(parse_file(content))
  end

  # ── top-level type counters ─────────────────────────────────────────────────

  def test_single_task_gets_task_1
    r = resolver_for("@task[]{\n  first task\n}")
    epoch_key = "#{DATE_INT}.1"
    assert_equal "task-1", r.to_human(epoch_key)
    assert_equal epoch_key, r.to_epoch("task-1")
  end

  def test_multiple_types_counted_independently
    r = resolver_for("@task[]{\n  t1\n}\n@note[]{\n  n1\n}\n@task[]{\n  t2\n}")
    assert_equal "task-1", r.to_human("#{DATE_INT}.1")
    assert_equal "note-1", r.to_human("#{DATE_INT}.2")
    assert_equal "task-2", r.to_human("#{DATE_INT}.3")
  end

  def test_mps_container_gets_mps_counter
    r = resolver_for("@mps[]{\n  @task[]{\n    inner\n  }\n}")
    assert_equal "mps-1", r.to_human("#{DATE_INT}.1")
  end

  # ── nested element refs ─────────────────────────────────────────────────────

  def test_nested_element_gets_parent_dot_index
    r = resolver_for("@mps[]{\n  @task[]{\n    inner task\n  }\n}")
    # epoch.1 = mps-1, epoch.1.1 = mps-1.1
    assert_equal "mps-1.1", r.to_human("#{DATE_INT}.1.1")
    assert_equal "#{DATE_INT}.1.1", r.to_epoch("mps-1.1")
  end

  def test_multiple_nested_elements_sequential_index
    content = "@mps[]{\n  @task[]{\n    a\n  }\n  @note[]{\n    b\n  }\n}"
    r = resolver_for(content)
    assert_equal "mps-1.1", r.to_human("#{DATE_INT}.1.1")
    assert_equal "mps-1.2", r.to_human("#{DATE_INT}.1.2")
  end

  def test_deeply_nested_extends_path
    content = "@mps[]{\n  @mps[]{\n    @task[]{\n      deep\n    }\n  }\n}"
    r = resolver_for(content)
    # epoch.1 = mps-1, epoch.1.1 = mps-1.1, epoch.1.1.1 = mps-1.1.1
    assert_equal "mps-1.1.1", r.to_human("#{DATE_INT}.1.1.1")
  end

  # ── resolve method ──────────────────────────────────────────────────────────

  def test_resolve_human_ref
    r = resolver_for("@task[]{\n  task\n}")
    epoch_key = "#{DATE_INT}.1"
    assert_equal epoch_key, r.resolve("task-1")
  end

  def test_resolve_epoch_ref
    r = resolver_for("@task[]{\n  task\n}")
    epoch_key = "#{DATE_INT}.1"
    assert_equal epoch_key, r.resolve(epoch_key)
  end

  def test_resolve_unknown_ref_returns_nil
    r = resolver_for("@task[]{\n  task\n}")
    assert_nil r.resolve("task-99")
  end

  def test_to_human_unknown_returns_nil
    r = resolver_for("@task[]{\n  task\n}")
    assert_nil r.to_human("99999999.99")
  end

  def test_to_epoch_unknown_returns_nil
    r = resolver_for("@task[]{\n  task\n}")
    assert_nil r.to_epoch("note-1")
  end

  # ── empty elements hash ─────────────────────────────────────────────────────

  def test_empty_elements_hash
    r = RefResolver.new({})
    assert_nil r.to_human("anything")
    assert_nil r.to_epoch("task-1")
  end
end
