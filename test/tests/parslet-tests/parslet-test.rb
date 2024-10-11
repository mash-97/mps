require 'parslet'

class DemoParser < Parslet::Parser
  rule(:identifier){ match('[a-z]').repeat(1) }
  rule(:number){ match('[0-9]').repeat(1) }
  rule(:space){ match('\s').repeat(0) }
  rule(:line){ identifier >> space >> number }

  root(:line)
end

demo_parser = DemoParser.new
result = demo_parser.parse("foo 1")
puts result.inspect

