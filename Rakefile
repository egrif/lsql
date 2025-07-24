# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run all tests and linting'
task check: %i[spec rubocop]

task default: :check

desc 'Install the application locally'
task :install do
  puts 'Installing lsql application...'

  # Create symlink to make it globally available
  home_bin = File.expand_path('~/bin')
  FileUtils.mkdir_p(home_bin)

  source = File.expand_path('bin/lsql')
  target = File.join(home_bin, 'lsql')

  File.unlink(target) if File.exist?(target) || File.symlink?(target)

  File.symlink(source, target)
  puts "Installed lsql to #{target}"
  puts "Make sure #{home_bin} is in your PATH"
end

desc 'Uninstall the application'
task :uninstall do
  target = File.expand_path('~/bin/lsql')
  if File.exist?(target) || File.symlink?(target)
    File.unlink(target)
    puts "Uninstalled lsql from #{target}"
  else
    puts 'lsql is not installed'
  end
end
