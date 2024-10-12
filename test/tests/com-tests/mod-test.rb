require 'commander'

include Commander::Methods
module M
  command :hexa do |c|
    c.action do |args, options|
      puts("inside hexa> args: #{args.to_s}, options: #{options.to_s}")
    end
  end
end

