require 'minitest/autorun'
require_relative 'task.rb'

STR2 = "#task1 @[:task]{this is the content of the first task. #task1 @[:task]{this is the content of the first task.}}"
class TestTask < Minitest::Test
  #attr_accessor :str1, :str2
  class << self
    attr_accessor :str1, :str2
  end
  def setup
    @@str1 = "#task1 @[:task]{this is the content of the first task.}"
    @@str2 = "#task1 @[:task]{this is the content of the first task. #task1 @[:task]{this is the content of the first task.}}"
    @@valid_strs = <<STR
      valid tasks:
      #task @[:task]{}
      #task1 @[:task]{this is the content of the first task.}
      #task2 @[:task, :time, :context, let's check']{also a valid task with valid args.}
      #task3 @[:task, :creation_timestamp, :due_timestamp, :priority, :status]{a valid task with many args}
      #task4 @[ :task , :creation_timestamp, :due_timestamp, :priority, :status]{a valid task with many args}
STR
    @@invalid_strs = <<STR
      invalid tasks:
      @[:reminder]{}
      @[:]
STR
  end
  def test_strs()
    t = Task::from_str(@@str1)
    assert(t)
    puts(t.inspect)
    t = Task::from_str(@@str2)
    assert(t)
    puts(t.inspect)
  end
end
