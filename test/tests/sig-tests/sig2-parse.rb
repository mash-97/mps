require 'strscan'

# Regular expressions with clearer names
ANNOTATION_START_LOOKAHEAD = /(?=@[a-zA-Z0-9_,:\s]+?\[.*?\]\s*?\{)/
ANNOTATION_PATTERN = /@([a-zA-Z0-9_,:\s]+?)\[(.*?)\]\s*?\{/
BLOCK_END_LOOKAHEAD = /(?=(?<!')\}(?!'))/
BLOCK_END_PATTERN = /(?<!')\}(?!')/

if $0 == __FILE__
  fc = File.read(ARGV.first) 
  ss = StringScanner.new("@mps[]{"+fc+"}")
  conts = []
  stack = []
  at_first = true
  ref_stack = [2024]
  while !ss.eos?
    if at_first && ss.scan_until(ANNOTATION_START_LOOKAHEAD)
      sp = ss.pos
      ss.scan_until(ANNOTATION_PATTERN)
      ep = ss.pos - 1
      match_data = ss.string[sp..ss.pos].match(ANNOTATION_PATTERN)
      puts("matched: #{match_data}")
      stack << [[match_data[1], match_data[2]], ep + 1]
      #           stamp             args          end-position/starting of the main body
    
    elsif !at_first && ss.scan_until(BLOCK_END_PATTERN) && !stack.empty?
      stack_top = stack.pop
      conts << stack_top.first
      conts.last << ss.string[stack_top.last...ss.pos-2].strip
      conts.last.unshift ref_stack.map(&:to_s).join(".")
      ref_stack[-1] += 1
    end

    at_pos = ss.string.size
    bra_pos = ss.string.size

    if ss.scan_until(ANNOTATION_START_LOOKAHEAD)
      at_pos = ss.pos
      ss.unscan
    end

    if ss.scan_until(BLOCK_END_LOOKAHEAD)
      bra_pos = ss.pos
      ss.unscan
    end

    if at_pos<bra_pos and at_first
      ref_stack << 1
    elsif at_pos>bra_pos and !at_first
      ref_stack.pop()
    end

    at_first = at_pos < bra_pos
    ss.pos = [at_pos, bra_pos].min
  end

  conts.each do |x|
    puts("#{x.first}\t#{x[1]}\t[ #{x[2]} ]\t{#{x.last[..10]}..}")
  end
  puts("#> stack: #{stack}")
end

