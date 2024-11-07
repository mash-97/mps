require 'cli/ui'
require 'git'
system("git status")

branch = CLI::UI.ask("which branch to apply gitauto? ", options: Git.open(".").branches.local.collect{|x|x.name})

system("git checkout #{branch}")
system("git status")
system("git add .")
system("git commit -m \"#{Time.now}\"")
system("git pull origin #{branch}")
system("git push origin #{branch}")
