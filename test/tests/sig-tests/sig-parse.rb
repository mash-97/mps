require 'strscan'

AT_REGEXP_GI = /(?=@[a-zA-Z0-9_,:\s]+?\[.*?\]\s*?\{)/
AT_REGEXP = /@([a-zA-Z0-9_,:\s]+?)\[(.*?)\]\s*?{/
CURLY_EBRA_REGEXP_GI = /(?=(?<!')\}(?!'))/
CURLY_EBRA_REGEXP = /(?<!')\}(?!')/


if $0 == __FILE__
  fc = File.open(ARGV.first, "r").read()
  ss = StringScanner.new(fc)
  conts = []
  stack = []
  at_first = true
  while !ss.eos?
    # puts("at pos: #{ss.pos}")
    if at_first and ss.scan_until(AT_REGEXP_GI)
      sp = ss.pos # exact pos of @
      ss.scan_until(AT_REGEXP)
      ep = ss.pos-1 # exact pos of {
      ss.string[sp..ss.pos].match(AT_REGEXP)
      puts("matched: #{$~}") 
      # push it to the stack
      stack << [[$1, $2], ep+2] 
      

    elsif !at_first and ss.scan_until(CURLY_EBRA_REGEXP) and !stack.empty?
      stack_top = stack.pop()
      conts << stack_top.first
      conts.last << ss.string[stack_top.last...ss.pos-2].strip()
    end
    # next at or bra check
    # possible next match 
    # if the position of the matched AT_REGEXP_GI 
    # smaller than the matched CURLY_EBRA_REGEXP_GI 
    #   then go to the next cycle
    #   else process the stack
    #   also if neither next match, break with raise if stack not empty or clean break
    at_pos = ss.string.size
    bra_pos = ss.string.size
    if ss.scan_until(AT_REGEXP_GI) then
      at_pos = ss.pos
      ss.unscan
    end
    if ss.scan_until(CURLY_EBRA_REGEXP_GI) 
      bra_pos = ss.pos
      ss.unscan
    end
    if at_pos < bra_pos
      at_first = true
    else
      at_first = false
    end
    ss.pos += 1
  end
  conts.each do |x|
    puts("#{x.first}\t#{x[1..]}")
  end
  puts("#> stack: #{stack}")
end

