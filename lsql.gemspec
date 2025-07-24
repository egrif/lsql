# frozen_string_literal: true

require_relative 'lib/lsql/version'

Gem::Specification.new do |spec|
  spec.name = 'lsql'
  spec.version = Lsql::VERSION
  spec.authors = ['Eric Griffith']
  spec.email = ['eric.griffith@example.com']

  spec.summary = 'Command-line SQL tool for Lotus environments'
  spec.description = 'A Ruby-based command-line tool for executing SQL queries against Lotus environments with support for groups, parallel execution, and caching.'
  spec.homepage = 'https://github.com/egrif/lsql'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/egrif/lsql'
  spec.metadata['changelog_uri'] = 'https://github.com/egrif/lsql/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = ['lsql']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'moneta', '>= 1.0', '< 2.0'
  spec.add_dependency 'redis', '>= 4.0', '< 6.0'
  spec.add_dependency 'concurrent-ruby', '>= 1.1', '< 2.0'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
end
