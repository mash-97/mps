require 'parslet'

class TaskParser < Parslet::Parser
  # Define basic tokens
  rule(:space)         { match('\s').repeat(1) }
  rule(:space?)        { space.maybe }
  rule(:at_sign)       { str('@') }
  rule(:colon)         { str(':') }
  rule(:comma)         { str(',') >> space? }
  rule(:open_bracket)  { str('[') }
  rule(:close_bracket) { str(']') }
  rule(:open_brace)    { str('{') }
  rule(:close_brace)   { str('}') }

  # Define basic patterns
  rule(:identifier)    { match('[a-zA-Z_]').repeat(1) }
  rule(:word)          { match('[a-zA-Z0-9]').repeat(1) }
  rule(:text)          { match('[^{}]').repeat(1).as(:text) }

  # Define a task pattern, something like: @[:task, a, b, c]
  rule(:task_type)     { at_sign >> open_bracket >> colon >> identifier.as(:task_type) >> comma >> (identifier.as(:arg) >> comma.maybe).repeat >> close_bracket }

  # Define the task body inside { ... }
  rule(:task_body)     { open_brace >> (task_type | text | space?).repeat.as(:body) >> close_brace }

  # A complete task looks like @[:task, a, b, c]{...}
  rule(:task)          { task_type.as(:header) >> task_body }

  # Root rule (entry point for parsing)
  root(:task)
end

class TaskTransform < Parslet::Transform
  rule(task_type: simple(:task_type), arg: sequence(:args)) do
    { task_type: task_type.to_s, args: args.map(&:to_s) }
  end

  rule(body: sequence(:body)) do
    body.map(&:to_s).join
  end
end

# Example usage:
parser = TaskParser.new
transform = TaskTransform.new

input = '@[:task, a, b, c]{ this is a task. below set a reminder: @[:reminder, time, everyday]{$(:context)} }'

begin
  parsed = parser.parse(input)
  transformed = transform.apply(parsed)
  puts transformed
rescue Parslet::ParseFailed => error
  puts "Parsing failed: #{error.parse_failure_cause.ascii_tree}"
end

