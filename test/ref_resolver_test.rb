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

  # ── non-@mps parent containers (task-in-task, note-in-task) ────────────────

  def test_task_nested_in_task_gets_parent_dot_ref
    content = "@task[]{\n  outer\n  @task[]{\n    inner\n  }\n}"
    r = resolver_for(content)
    # outer task at depth 1 → task-1
    assert_equal "task-1",   r.to_human("#{DATE_INT}.1"),   "outer task → task-1"
    # inner task at depth 2 → task-1.1 (NOT task-2)
    assert_equal "task-1.1", r.to_human("#{DATE_INT}.1.1"), "inner task → task-1.1"
    assert_equal "#{DATE_INT}.1.1", r.to_epoch("task-1.1"), "roundtrip"
  end

  def test_note_nested_in_task_gets_parent_dot_ref
    content = "@task[]{\n  task body\n  @note[]{\n    inner note\n  }\n}"
    r = resolver_for(content)
    assert_equal "task-1",   r.to_human("#{DATE_INT}.1"),   "task → task-1"
    assert_equal "task-1.1", r.to_human("#{DATE_INT}.1.1"), "note in task → task-1.1 (not note-1)"
    assert_nil r.to_epoch("note-1"), "nested note does not get a top-level note counter"
  end

  def test_type_counter_excludes_nested_tasks
    # Nested tasks do not increment the top-level type counter.
    content = "@task[]{\n  outer\n  @task[]{ inner1 }\n  @task[]{ inner2 }\n}\n@task[]{\n  sibling\n}"
    r = resolver_for(content)
    assert_equal "task-1",   r.to_human("#{DATE_INT}.1"),   "outer task → task-1"
    assert_equal "task-2",   r.to_human("#{DATE_INT}.2"),   "sibling task → task-2 (counter=2)"
    assert_equal "task-1.1", r.to_human("#{DATE_INT}.1.1"), "inner task 1 → task-1.1"
    assert_equal "task-1.2", r.to_human("#{DATE_INT}.1.2"), "inner task 2 → task-1.2"
    assert_nil r.to_epoch("task-3"), "no task-3 — inner tasks do not inflate counter"
    assert_nil r.to_epoch("task-4"), "no task-4"
  end

  def test_three_levels_task_task_note
    content = "@task[]{\n  outer\n  @task[]{\n    mid\n    @note[]{\n      leaf note\n    }\n  }\n}"
    r = resolver_for(content)
    assert_equal "task-1",     r.to_human("#{DATE_INT}.1"),     "outer → task-1"
    assert_equal "task-1.1",   r.to_human("#{DATE_INT}.1.1"),   "mid task → task-1.1"
    assert_equal "task-1.1.1", r.to_human("#{DATE_INT}.1.1.1"), "leaf note → task-1.1.1"
    assert_equal "#{DATE_INT}.1.1.1", r.to_epoch("task-1.1.1"), "roundtrip"
  end

  def test_multiple_children_in_task_sequential_indices
    content = "@task[]{\n  outer\n  @task[]{ t1 }\n  @note[]{ n1 }\n  @task[]{ t2 }\n}"
    r = resolver_for(content)
    assert_equal "task-1.1", r.to_human("#{DATE_INT}.1.1"), "first child (task) → task-1.1"
    assert_equal "task-1.2", r.to_human("#{DATE_INT}.1.2"), "second child (note) → task-1.2"
    assert_equal "task-1.3", r.to_human("#{DATE_INT}.1.3"), "third child (task) → task-1.3"
  end

  def test_sibling_at_top_level_after_nested_container
    # After a nested container task, a sibling gets the next top-level counter.
    content = "@task[]{\n  container\n  @task[]{ nested }\n}\n@note[]{\n  top note\n}"
    r = resolver_for(content)
    assert_equal "task-1", r.to_human("#{DATE_INT}.1"), "container task → task-1"
    assert_equal "note-1", r.to_human("#{DATE_INT}.2"), "top-level note → note-1"
    assert_nil r.to_epoch("task-2"), "no task-2 (nested task is task-1.1)"
  end

  def test_note_in_task_roundtrip
    content = "@task[]{\n  t\n  @note[]{ n }\n}"
    r = resolver_for(content)
    assert_equal "#{DATE_INT}.1.1", r.to_epoch(r.to_human("#{DATE_INT}.1.1")), "roundtrip"
    assert_equal "#{DATE_INT}.1",   r.to_epoch(r.to_human("#{DATE_INT}.1")),   "roundtrip"
  end
end
