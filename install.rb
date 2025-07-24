#!/usr/bin/env ruby
# frozen_string_literal: true

# LSQL Installer Script
# This script installs the latest version of lsql directly from the GitHub repository

require 'tmpdir'
require 'fileutils'

def run_command(command)
  puts "Running: #{command}"
  system(command) || abort("Command failed: #{command}")
end

def install_lsql
  puts 'Installing LSQL from GitHub repository...'

  Dir.mktmpdir do |tmpdir|
    puts "Working in temporary directory: #{tmpdir}"

    # Clone the repository
    run_command("git clone https://github.com/egrif/lsql.git #{tmpdir}/lsql")

    # Change to the lsql directory
    Dir.chdir("#{tmpdir}/lsql") do
      puts 'Building gem...'
      run_command('gem build lsql.gemspec')

      # Find the built gem file
      gem_file = Dir.glob('lsql-*.gem').first
      abort('No gem file found!') unless gem_file

      puts "Installing gem: #{gem_file}"
      run_command("gem install #{gem_file}")
    end
  end

  puts "\n✅ LSQL installation complete!"
  puts "You can now run 'lsql --help' to get started."
end

# Check if git is available
abort('❌ Git is required but not found. Please install git first.') unless system('which git > /dev/null 2>&1')

# Check if gem is available
abort('❌ RubyGems is required but not found. Please install Ruby first.') unless system('which gem > /dev/null 2>&1')

# Run the installation
install_lsql
