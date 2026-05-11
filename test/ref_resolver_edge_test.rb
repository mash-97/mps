# frozen_string_literal: true

require_relative "test_helper"

# Edge-case tests for RefResolver, supplementing ref_resolver_test.rb.
class RefResolverEdgeTest < Minitest::Test
  include MPS

  ASSETS = File.expand_path("assets", __dir__)

  def parse(filename)
    path = File.join(ASSETS, filename)
    ec = Elements.constants.map { |k| Elements.const_get(k) }.select { |x| x.class == Class }
    Engines::Parser.parse_mps_file_to_elements_hash(path, ec)
  end

  def resolver_for(filename)
    RefResolver.new(parse(filename))
  end

  # ── Unknown elements at depth 1 get no human ref ────────────────────────────

  def test_unknowns_at_depth1_excluded_from_map
    r = resolver_for("20260306.1000000105.mps")
    all = parse("20260306.1000000105.mps")
    unknown_refs = all.select { |_, e| e.is_a?(Engines::Parser::Unknown) }.keys
    unknown_refs.each do |ref|
      assert_nil r.to_human(ref),
                 "unknown element at depth 1 should have no human ref (#{ref})"
    end
  end

  def test_unknowns_dont_increment_type_counters
    r = resolver_for("20260306.1000000105.mps")
    all = parse("20260306.1000000105.mps")

    task_ref = all.find { |_, e| e.is_a?(Elements::Task) }&.first
    note_ref = all.find { |_, e| e.is_a?(Elements::Note) }&.first
    log_ref  = all.find { |_, e| e.is_a?(Elements::Log) }&.first

    assert_equal "task-1", r.to_human(task_ref)
    assert_equal "note-1", r.to_human(note_ref)
    assert_equal "log-1",  r.to_human(log_ref)
  end

  # ── Many same-type elements get sequential counters ──────────────────────────

  def test_many_tasks_sequential_human_refs
    r = resolver_for("20260303.1000000102.mps")
    all = parse("20260303.1000000102.mps")
    task_refs = all.select { |_, e| e.is_a?(Elements::Task) }
                   .sort_by { |k, _| k.split(".").map(&:to_i) }
                   .map(&:first)

    task_refs.each_with_index do |epoch_ref, i|
      expected = "task-#{i + 1}"
      assert_equal expected, r.to_human(epoch_ref),
                   "task #{i + 1} should have human ref '#{expected}'"
    end
  end

  def test_many_notes_sequential_human_refs
    r = resolver_for("20260303.1000000102.mps")
    all = parse("20260303.1000000102.mps")
    note_refs = all.select { |_, e| e.is_a?(Elements::Note) }
                   .sort_by { |k, _| k.split(".").map(&:to_i) }
                   .map(&:first)

    note_refs.each_with_index do |epoch_ref, i|
      assert_equal "note-#{i + 1}", r.to_human(epoch_ref)
    end
  end

  def test_reverse_lookup_for_many_tasks
    r = resolver_for("20260303.1000000102.mps")
    all = parse("20260303.1000000102.mps")
    task_refs = all.select { |_, e| e.is_a?(Elements::Task) }
                   .sort_by { |k, _| k.split(".").map(&:to_i) }
                   .map(&:first)

    task_refs.each_with_index do |epoch_ref, i|
      human = "task-#{i + 1}"
      assert_equal epoch_ref, r.to_epoch(human)
    end
  end

  # ── Complex nested MPS: ref paths ───────────────────────────────────────────

  def test_complex_nested_task_has_human_ref
    r = resolver_for("20260309.1000000108.mps")
    all = parse("20260309.1000000108.mps")
    tasks = all.select { |_, e| e.is_a?(Elements::Task) }
    tasks.each do |epoch_ref, _|
      refute_nil r.to_human(epoch_ref), "every task should have a human ref (#{epoch_ref})"
    end
  end

  def test_complex_nested_sub_milestone_task_has_nested_ref
    r = resolver_for("20260309.1000000108.mps")
    all = parse("20260309.1000000108.mps")
    api_task = all.find { |_, e| e.is_a?(Elements::Task) && e.body_str.strip == "Write API integration tests" }
    refute_nil api_task
    human = r.to_human(api_task.first)
    refute_nil human
    assert human.include?("."), "deeply nested task should have dotted human ref (#{human})"
  end

  # ── 5-level nesting ref paths ────────────────────────────────────────────────

  def test_five_level_deep_task_has_human_ref
    r = resolver_for("20260313.1000000112.mps")
    all = parse("20260313.1000000112.mps")
    five_deep = all.find { |_, e| e.is_a?(Elements::Task) && e.body_str.strip == "Five levels deep" }
    refute_nil five_deep
    human = r.to_human(five_deep.first)
    refute_nil human
  end

  def test_five_level_all_tasks_have_distinct_refs
    r = resolver_for("20260313.1000000112.mps")
    all = parse("20260313.1000000112.mps")
    task_refs = all.select { |_, e| e.is_a?(Elements::Task) }
    human_refs = task_refs.map { |k, _| r.to_human(k) }.compact
    assert_equal human_refs.size, human_refs.uniq.size, "all tasks must have distinct human refs"
  end

  # ── Epoch-less file ref format ───────────────────────────────────────────────

  def test_epoch_less_file_task_human_ref
    r = resolver_for("20260310.mps")
    all = parse("20260310.mps")
    task_ref = all.find { |_, e| e.is_a?(Elements::Task) }&.first
    assert_equal "task-1", r.to_human(task_ref)
  end

  def test_epoch_less_file_reverse_lookup
    r = resolver_for("20260310.mps")
    all = parse("20260310.mps")
    task_ref = all.find { |_, e| e.is_a?(Elements::Task) }&.first
    assert_equal task_ref, r.to_epoch("task-1")
  end

  # ── resolve() works for both human and epoch forms ───────────────────────────

  def test_resolve_human_form_in_complex_file
    r = resolver_for("20260308.1000000107.mps")
    epoch = r.to_epoch("task-2")
    refute_nil epoch
    assert_equal epoch, r.resolve("task-2")
  end

  def test_resolve_epoch_form_in_complex_file
    r = resolver_for("20260308.1000000107.mps")
    all = parse("20260308.1000000107.mps")
    first_task_ref = all.select { |_, e| e.is_a?(Elements::Task) }
                        .sort_by { |k, _| k.split(".").map(&:to_i) }
                        .first&.first
    assert_equal first_task_ref, r.resolve(first_task_ref)
  end

  # ── 20260308 duplicate-args file: all 5 tasks get distinct human refs ────────

  def test_duplicate_args_file_all_tasks_distinct_refs
    r = resolver_for("20260308.1000000107.mps")
    all = parse("20260308.1000000107.mps")
    task_refs = all.select { |_, e| e.is_a?(Elements::Task) }
    human_refs = task_refs.map { |k, _| r.to_human(k) }.compact
    assert_equal 5, human_refs.size
    assert_equal 5, human_refs.uniq.size, "all 5 tasks must have distinct human refs"
    assert_equal "task-1", human_refs.min_by { |h| h.split("-").last.to_i }
    assert_equal "task-5", human_refs.max_by { |h| h.split("-").last.to_i }
  end
end
