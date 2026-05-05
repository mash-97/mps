# frozen_string_literal: true

require_relative 'test_helper'

class EngineTest < Minitest::Test
  include Constants

  VALID_FAKE_FILENAME = "20260101.mps"

  def element_classes_fixture
    ::MPS::Elements.constants
      .map    { |k| ::MPS::Elements.const_get(k) }
      .select { |x| x.class == Class }
  end

  def parse_content(content)
    FakeFS.with_fresh do
      FileUtils.mkdir_p("/tmp")
      path = "/tmp/#{VALID_FAKE_FILENAME}"
      File.write(path, content)
      ::MPS::Engines::Parser.parse_mps_file_to_elements_hash(path, element_classes_fixture)
    end
  end

  def test_parse_empty_file
    elements = parse_content("")
    assert_instance_of Hash, elements
    mps_elements = elements.values.select { |e| e.class == ::MPS::Elements::MPS }
    assert_equal 1, mps_elements.size
  end

  def test_parse_single_task
    content = "@task[]{\n  do the thing\n}"
    elements = parse_content(content)
    tasks = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert_equal 1, tasks.size
    assert_equal "do the thing", tasks.first.body_str.strip
  end

  def test_parse_multiple_elements
    content = "@task[]{\n  task one\n}\n@note[]{\n  a note\n}\n@log[]{\n  worked\n}"
    elements = parse_content(content)
    assert_equal 1, elements.values.count { |e| e.class == ::MPS::Elements::Task }
    assert_equal 1, elements.values.count { |e| e.class == ::MPS::Elements::Note }
    assert_equal 1, elements.values.count { |e| e.class == ::MPS::Elements::Log }
  end

  def test_parse_unknown_element
    content = "@foobar[]{\n  unknown stuff\n}"
    elements = parse_content(content)
    unknown = elements.values.reject { |e| e.class == ::MPS::Elements::MPS }
    assert_equal 1, unknown.size
    el = unknown.first
    assert_instance_of ::MPS::Engines::Parser::Unknown, el
    assert_equal "foobar", el.ecn
    assert_equal "unknown stuff", el.body_str.strip
    assert el.respond_to?(:ecn)
  end

  def test_parse_nested_mps
    content = "@mps[]{\n  @task[]{\n    nested task\n  }\n}"
    elements = parse_content(content)
    assert elements.size >= 3, "expected at least 3 elements (outer mps wrapper + inner mps + task), got #{elements.size}"
    assert elements.values.count { |e| e.class == ::MPS::Elements::MPS } >= 2
    task_els = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert_equal 1, task_els.size
    assert_equal "nested task", task_els.first.body_str.strip
  end

  def test_parse_sibling_elements_have_sequential_refs
    content = "@task[]{\n  A\n}\n@task[]{\n  B\n}\n@task[]{\n  C\n}"
    elements = parse_content(content)
    tasks = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert_equal 3, tasks.size
    task_refs = elements.select { |_, e| e.class == ::MPS::Elements::Task }.keys
    assert_equal 3, task_refs.uniq.size, "sibling tasks must have distinct ref keys"
  end

  def test_parse_deeply_nested
    content = "@mps[]{\n  @mps[]{\n    @task[]{\n      deep\n    }\n  }\n}"
    elements = parse_content(content)
    task_els = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert_equal 1, task_els.size
    assert_equal "deep", task_els.first.body_str.strip
    # ref depth should be 4 segments: epoch.1.1.1
    task_ref = elements.find { |_, e| e.class == ::MPS::Elements::Task }.first
    assert_equal 4, task_ref.split(".").size, "deeply nested task should have 4-segment ref"
  end

  def test_parse_args_captured
    content = "@log[start: 09:00, end: 12:30]{\n  worked\n}"
    elements = parse_content(content)
    log_els = elements.values.select { |e| e.class == ::MPS::Elements::Log }
    assert_equal 1, log_els.size
    assert_equal "start: 09:00, end: 12:30", log_els.first.raw_args
  end

  def test_matched_element_class_known
    result = ::MPS::Engines::Parser.matched_element_class("task", element_classes_fixture)
    assert_equal ::MPS::Elements::Task, result
  end

  def test_matched_element_class_unknown
    result = ::MPS::Engines::Parser.matched_element_class("nonexistent_xyz", element_classes_fixture)
    assert_nil result
  end

  # ── old colon-prefix arg syntax (e.g. @task[:pending]) ────────────────────

  def test_parse_colon_prefix_args_does_not_crash
    content = "@task[:pending]{\n  old style task\n}"
    elements = parse_content(content)
    tasks = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert_equal 1, tasks.size
    assert_equal "old style task", tasks.first.body_str.strip
  end

  def test_parse_colon_prefix_args_has_default_status
    content = "@task[:pending]{\n  old style task\n}"
    elements = parse_content(content)
    task = elements.values.find { |e| e.class == ::MPS::Elements::Task }
    # ":pending" is an unrecognized colon-prefix token; status falls back to schema default
    assert_equal "open", task.parsed_args[:status], "colon-prefix arg falls back to default status"
    assert task.open?, "task should be considered open"
  end

  # ── @task nested inside @log (structurally valid) ─────────────────────────

  def test_task_nested_inside_log
    content = "@log[]{\n  work session\n  @task[]{\n    nested task\n  }\n}"
    elements = parse_content(content)
    assert elements.values.any? { |e| e.class == ::MPS::Elements::Log }
    assert elements.values.any? { |e| e.class == ::MPS::Elements::Task }
    task = elements.values.find { |e| e.class == ::MPS::Elements::Task }
    assert_equal "nested task", task.body_str.strip
  end

  # ── body text with #hashtag is NOT parsed as a tag ─────────────────────────

  def test_hashtag_in_body_is_not_a_mps_tag
    content = "@log[]{\n  went to the gym #health #fitness\n}"
    elements = parse_content(content)
    log_el = elements.values.find { |e| e.class == ::MPS::Elements::Log }
    refute_nil log_el
    assert log_el.tags.empty?, "# hash-style body tags should not be parsed as MPS tags"
    assert_match(/#health/, log_el.body_str)
  end

end
