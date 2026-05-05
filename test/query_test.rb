# frozen_string_literal: true

require_relative "test_helper"

class QueryTest < Minitest::Test
  include MPS

  def task(args: "", body: "task", refs: [1])
    Elements::Task.new(args: args, refs: refs, body_str: body)
  end

  def note(args: "", body: "note", refs: [2])
    Elements::Note.new(args: args, refs: refs, body_str: body)
  end

  def log(args: "start: 09:00, end: 11:00", body: "log", refs: [3])
    Elements::Log.new(args: args, refs: refs, body_str: body)
  end

  def mps_el(refs: [4])
    Elements::MPS.new(args: "", refs: refs, body_str: "")
  end

  def elements_hash(*els)
    els.each_with_index.to_h { |el, i| ["20260101.#{i + 1}", el] }
  end

  # ── MPS containers always excluded ─────────────────────────────────────────

  def test_mps_containers_excluded
    h = elements_hash(task, mps_el)
    result = Query.new.apply(h)
    assert_equal 1, result.size
    refute result.values.any? { |e| e.is_a?(Elements::MPS) }
  end

  # ── type filter ─────────────────────────────────────────────────────────────

  def test_type_filter_keeps_matching
    h = elements_hash(task, note)
    result = Query.new(type: "task").apply(h)
    assert_equal 1, result.size
    assert result.values.all? { |e| e.is_a?(Elements::Task) }
  end

  def test_type_filter_excludes_non_matching
    h = elements_hash(task, note)
    result = Query.new(type: "log").apply(h)
    assert result.empty?
  end

  # ── tag filter ──────────────────────────────────────────────────────────────

  def test_tag_filter
    h = elements_hash(task(args: "work"), note(args: "personal"))
    result = Query.new(tag: "work").apply(h)
    assert_equal 1, result.size
    assert_equal %w[work], result.values.first.tags
  end

  # ── schema-driven attr filter (status) ──────────────────────────────────────

  def test_status_filter_done
    h = elements_hash(
      task(args: "status: done"),
      task(args: "status: open")
    )
    result = Query.new(status: "done").apply(h)
    assert_equal 1, result.size
    assert_equal "done", result.values.first.parsed_args[:status]
  end

  def test_status_filter_excludes_notes
    h = elements_hash(
      task(args: "status: open"),
      note(args: "work")
    )
    result = Query.new(status: "open").apply(h)
    assert_equal 1, result.size
    assert result.values.all? { |e| e.is_a?(Elements::Task) }
  end

  # ── apply_for_tree ──────────────────────────────────────────────────────────

  def test_apply_for_tree_keeps_mps_when_children_visible
    inner_task = task(refs: [1, 1])
    mps        = mps_el(refs: [1])
    h = { "20260101.1" => mps, "20260101.1.1" => inner_task }
    result = Query.new(type: "task").apply_for_tree(h)
    assert result.key?("20260101.1"),   "mps container should remain"
    assert result.key?("20260101.1.1"), "inner task should remain"
  end

  def test_apply_for_tree_removes_mps_when_no_visible_children
    inner_note = note(refs: [1, 1])
    mps        = mps_el(refs: [1])
    h = { "20260101.1" => mps, "20260101.1.1" => inner_note }
    result = Query.new(type: "task").apply_for_tree(h)
    refute result.key?("20260101.1"),   "mps container should be removed"
    refute result.key?("20260101.1.1"), "non-matching child should be removed"
  end

  # ── no filters ──────────────────────────────────────────────────────────────

  def test_no_filters_returns_all_non_mps
    h = elements_hash(task, note, log)
    result = Query.new.apply(h)
    assert_equal 3, result.size
  end

  # ── public match? API ───────────────────────────────────────────────────────

  def test_match_is_public
    q = Query.new(type: "task")
    assert q.match?(task), "match? should return true for matching element"
    refute q.match?(note), "match? should return false for non-matching element"
  end

  def test_match_no_filters_always_true_for_known_elements
    q = Query.new
    assert q.match?(task)
    assert q.match?(note)
    assert q.match?(log)
  end

  # ── Unknown element guard ───────────────────────────────────────────────────

  def test_unknown_elements_never_match
    unknown = Engines::Parser::Unknown.new("custom", "", [1], "body")
    q_none  = Query.new
    q_type  = Query.new(type: "custom")
    q_tag   = Query.new(tag: "work")
    refute q_none.match?(unknown), "Unknown should not match even with no filters"
    refute q_type.match?(unknown), "Unknown should not match type filter"
    refute q_tag.match?(unknown),  "Unknown should not raise or match tag filter"
  end

  def test_apply_excludes_unknown_elements
    unknown = Engines::Parser::Unknown.new("custom", "", [5], "body")
    h = elements_hash(task, note).merge("20260101.5" => unknown)
    result = Query.new.apply(h)
    assert_equal 2, result.size
    refute result.values.any? { |e| e.is_a?(Engines::Parser::Unknown) }
  end
end
