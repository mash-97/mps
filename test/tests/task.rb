

# This class for task parses task and subtasks from raw_str
class Task
  attr_accessor :creation_date, :note, :due_date, :priority, :status, :subtasks, :tags
  attr_accessor :args, :main_cont
  TASK_REGEXP = /(@\[\s*?:task\s*?,{0,1}?([\S\s]*?)\s*?\]\{([\S\s]*?)\})/
  STATUSES = [:discarded, :pending, :completed].each_with_index.to_h
  PRIORITIES = [:low, :medium, :top].each_with_index.to_h

  def initialize(args, main_cont, subtasks=[])
    @args = args
    @main_cont = main_cont
    @subtasks = subtasks
  end

  class << self
    def unwrap_task_through_regexp(raw_str)
      if raw_str.match(TASK_REGEXP)
        return {
          :original_cont => $1,
          :args_cont => $2,
          :main_cont => $3
        }
      end
      return nil
    end

    def from_str(str)
      r = unwrap_task_through_regexp(str)
      if r!=nil and r.class == Hash then
        task = Task.new(r[:args_cont], r[:main_cont])
        task.main_cont.scan(TASK_REGEXP).each_with_index.collect do |str, indx|
          puts("#> #{indx}: #{str}")
          task.subtasks << from_str(str)
        end
        return task
      end
      nil
    end
  end
end
