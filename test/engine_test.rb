# frozen_string_literal: true

require_relative 'test_helper'

class EngineTest < Minitest::Test
  include Constants

  VALID_FAKE_FILENAME = "20260101.mps"

  def element_classes_fixture
    ::MPS::Elements.constants
      .map { |k| ::MPS::Elements.const_get(k) }
      .select { |x| x.class == Class }
  end

  def parse_content(content)
    FakeFS.with_fresh do
      FileUtils.mkdir_p("/tmp")
      path = "/tmp/#{VALID_FAKE_FILENAME}"
      File.write(path, content)
      ::MPS::Engines::MPS.parse_mps_file_to_elments_hash(path, element_classes_fixture)
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
    task_els = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    note_els = elements.values.select { |e| e.class == ::MPS::Elements::Note }
    log_els  = elements.values.select { |e| e.class == ::MPS::Elements::Log }
    assert_equal 1, task_els.size
    assert_equal 1, note_els.size
    assert_equal 1, log_els.size
  end

  def test_parse_unknown_element
    content = "@foobar[]{\n  unknown stuff\n}"
    elements = parse_content(content)
    unknown = elements.values.reject { |e| e.class == ::MPS::Elements::MPS }
    assert_equal 1, unknown.size
    assert unknown.first.respond_to?(:ecn), "expected Struct with :ecn"
    assert_equal "foobar", unknown.first.ecn
  end

  def test_matched_element_class_known
    ec = element_classes_fixture
    result = ::MPS::Engines::MPS.matched_element_class("task", ec)
    assert_equal ::MPS::Elements::Task, result
  end

  def test_matched_element_class_unknown
    ec = element_classes_fixture
    result = ::MPS::Engines::MPS.matched_element_class("nonexistent_xyz", ec)
    assert_nil result
  end

  def test_parse_nested_mps
    content = "@mps[]{\n  @task[]{\n    nested task\n  }\n}"
    elements = parse_content(content)
    assert elements.size >= 3, "expected at least 3 elements (outer mps wrapper + inner mps + task), got #{elements.size}"
    mps_els  = elements.values.select { |e| e.class == ::MPS::Elements::MPS }
    task_els = elements.values.select { |e| e.class == ::MPS::Elements::Task }
    assert mps_els.size >= 2, "expected at least 2 MPS elements"
    assert_equal 1, task_els.size
    assert_equal "nested task", task_els.first.body_str.strip
  end

  def test_look_ahead_pos_no_match
    scanner = StringScanner.new("hello world no match here")
    scanner.scan(/hello /)
    pos = ::MPS::Engines::MPS.look_ahead_pos(scanner, /IMPOSSIBLE_PATTERN_XYZ/)
    assert_equal scanner.string.size, pos
  end
end
