# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2025-01-24

### Fixed
- Removed explicit optparse dependency to fix Ruby 3.1 compatibility issues
- Relaxed version constraints for redis, moneta, and concurrent-ruby dependencies for better compatibility across Ruby versions

## [1.1.0] - 2025-01-24log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-07-24

### Added
- **Parallel Execution**: Group operations now support parallel execution with `-p/--parallel` flag
  - Auto-detect CPU cores or specify custom thread count (e.g., `-p 4`)
  - Concurrent database queries for dramatically improved performance
  - Real-time progress tracking with spinners and completion counters
  - Thread-safe execution with proper error isolation

- **Unified Configuration System**: Moved all configuration to `~/.lsql/config.yml`
  - Combined cache settings and group definitions in single file
  - Global accessibility from any directory
  - Better organization under `~/.lsql/` directory
  - Enhanced configuration priority: CLI > config file > env vars > defaults

- **Automated Release Pipeline**: GitHub Actions for continuous integration and deployment
  - Automatic gem building and GitHub releases on version changes
  - Multi-Ruby version testing (3.0, 3.1, 3.2, 3.3)
  - Automated dependency updates with Dependabot

- **Enhanced Caching**: Improved cache management with configuration integration
  - Dynamic TTL configuration from config file
  - Cache prefix customization via config
  - Redis and file backend support with proper TTL handling

### Changed
- **Configuration Location**: Moved from `~/.lsql_config.yml` and `.lsql_groups.yml` to unified `~/.lsql/config.yml`
- **Group Configuration**: Groups now defined in main config file instead of separate project files
- **Help Documentation**: Enhanced with parallel execution examples and unified config information
- **Installation**: Now available as proper Ruby gem with system-wide `lsql` command

### Fixed
- Progress indicators properly handle concurrent execution
- Configuration priority resolution works correctly across all settings
- Cache statistics show dynamic TTL values from configuration

### Technical Improvements
- Added comprehensive test suite with RSpec
- Implemented proper gem structure with gemspec
- Added concurrent-ruby dependency for thread pool management
- Enhanced error handling and user feedback

## [1.0.0] - 2025-07-23

### Added
- Initial release with core functionality
- Single environment SQL execution
- Group-based batch operations
- Basic caching with Redis/file backends
- Environment-specific output aggregation
- Database connection mode support (rw, ro, replicas)
