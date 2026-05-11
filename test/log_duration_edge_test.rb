# frozen_string_literal: true

require_relative "test_helper"

# Edge-case tests for Log#duration_minutes and Log#duration_str.
# Fixture 20260305.1000000104.mps covers: near-full day, zero, partial, 45-minute.
class LogDurationEdgeTest < Minitest::Test
  include MPS

  ASSETS = File.expand_path("assets", __dir__)

  def parse_logs(filename)
    path = File.join(ASSETS, filename)
    ec = Elements.constants.map { |k| Elements.const_get(k) }.select { |x| x.class == Class }
    els = Engines::Parser.parse_mps_file_to_elements_hash(path, ec)
    els.values.select { |e| e.is_a?(Elements::Log) }
  end

  def log(args)
    Elements::Log.new(args: args, refs: [1], body_str: "work")
  end

  # ── Unit tests (no fixture needed) ─────────────────────────────────────────

  def test_duration_minutes_basic
    assert_equal 210, log("start: 09:00, end: 12:30").duration_minutes
  end

  def test_duration_str_hours_and_minutes
    assert_equal "3h30m", log("start: 09:00, end: 12:30").duration_str
  end

  def test_duration_str_exact_hours
    assert_equal "2h", log("start: 09:00, end: 11:00").duration_str
  end

  def test_duration_minutes_nil_without_start
    assert_nil log("end: 12:00").duration_minutes
  end

  def test_duration_minutes_nil_without_end
    assert_nil log("start: 09:00").duration_minutes
  end

  def test_duration_minutes_nil_without_either
    assert_nil log("work").duration_minutes
  end

  def test_duration_str_nil_when_minutes_nil
    assert_nil log("work").duration_str
  end

  def test_duration_minutes_zero_same_start_end
    assert_equal 0, log("start: 09:00, end: 09:00").duration_minutes
  end

  def test_duration_str_nil_for_zero_minutes
    assert_nil log("start: 09:00, end: 09:00").duration_str,
               "zero-duration session should return nil from duration_str"
  end

  def test_duration_str_sub_hour_format
    assert_equal "0h45m", log("start: 09:30, end: 10:15").duration_str,
                 "sub-hour durations are formatted as 0hNm"
  end

  def test_duration_minutes_45
    assert_equal 45, log("start: 09:30, end: 10:15").duration_minutes
  end

  def test_duration_str_30_minutes
    assert_equal "0h30m", log("start: 09:00, end: 09:30").duration_str
  end

  def test_duration_minutes_near_full_day
    assert_equal 1439, log("start: 00:00, end: 23:59").duration_minutes
  end

  def test_duration_str_near_full_day
    assert_equal "23h59m", log("start: 00:00, end: 23:59").duration_str
  end

  def test_duration_minutes_exactly_one_hour
    assert_equal 60, log("start: 09:00, end: 10:00").duration_minutes
  end

  def test_duration_str_exactly_one_hour
    assert_equal "1h", log("start: 09:00, end: 10:00").duration_str
  end

  # ── Fixture-based tests: 20260305 ──────────────────────────────────────────

  def test_fixture_near_full_day_duration
    logs = parse_logs("20260305.1000000104.mps")
    near_full = logs.find { |l| l.body_str.strip.include?("Near-full day") }
    assert_equal 1439, near_full.duration_minutes
    assert_equal "23h59m", near_full.duration_str
  end

  def test_fixture_zero_duration
    logs = parse_logs("20260305.1000000104.mps")
    zero = logs.find { |l| l.body_str.strip.include?("Zero duration") }
    assert_equal 0, zero.duration_minutes
    assert_nil zero.duration_str
  end

  def test_fixture_only_start_no_duration
    logs = parse_logs("20260305.1000000104.mps")
    only_start = logs.find { |l| l.body_str.strip.include?("Only start") }
    assert_nil only_start.duration_minutes
    assert_nil only_start.duration_str
  end

  def test_fixture_only_end_no_duration
    logs = parse_logs("20260305.1000000104.mps")
    only_end = logs.find { |l| l.body_str.strip.include?("Only end") }
    assert_nil only_end.duration_minutes
    assert_nil only_end.duration_str
  end

  def test_fixture_no_times_no_duration
    logs = parse_logs("20260305.1000000104.mps")
    no_times = logs.find { |l| l.body_str.strip.include?("No times") }
    assert_nil no_times.duration_minutes
    assert_nil no_times.duration_str
  end

  def test_fixture_forty_five_minutes
    logs = parse_logs("20260305.1000000104.mps")
    forty_five = logs.find { |l| l.body_str.strip.include?("Forty-five") }
    assert_equal 45, forty_five.duration_minutes
    assert_equal "0h45m", forty_five.duration_str
  end

  def test_fixture_all_six_logs_present
    logs = parse_logs("20260305.1000000104.mps")
    assert_equal 6, logs.size
  end
end
