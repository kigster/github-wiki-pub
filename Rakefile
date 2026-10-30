# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

# Rake ignores a task block's return value, so a failed command has to abort
# the task itself.
def shell(*args)
  command = args.join(" ")
  puts "running: #{command}"
  system(command) or abort "failed: #{command}"
end

CLEAN.include("pkg", "tmp", "coverage", "doc")

desc "Build the gem and install it locally"
task gem: [:build] do
  shell("gem install pkg/*")
end

desc "Make every file world-readable before packaging, except secrets"
task permissions: [:clean] do
  # .env files hold decrypted secrets (see .envrc), so they keep their permissions.
  shell("/usr/bin/find . -path ./.git -prune -o -name '.env*' -prune -o " \
        "-type d -exec chmod o+rx,g+rx {} + -o -type f -exec chmod o+r,g+r {} +")
end

Rake::Task[:build].enhance([:permissions])

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = %w[lib/**/*.rb exe/* - README.md LICENSE.txt]
  t.files << "CHANGELOG.md" if File.exist?("CHANGELOG.md")
  t.options.unshift("--title", Gem::Specification.load(Dir["*.gemspec"].first).summary)
  t.after = -> { exec("open doc/index.html") } if RUBY_PLATFORM.include?("darwin")
end

RSpec::Core::RakeTask.new(:spec)

task default: :spec
