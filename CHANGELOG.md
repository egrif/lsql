# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2025-01-05

### Added
- **Format Output Options**: New `-f/--format` option for structured data export
  - Supports CSV, TXT, JSON, and YAML output formats for non-interactive mode
  - CSV format preserves column headers and handles special characters properly
  - JSON and YAML formats use environment names as root keys for better organization
  - TXT format provides clean, readable plain text output
  - Works seamlessly with group operations and aggregated results
  - Format validation ensures only supported formats are accepted

- **Enhanced Prompt Customization**: New `--no-color/-C` option for prompt control
  - Disables ANSI color codes in interactive session prompts
  - Provides clean prompts suitable for automation and logging
  - Maintains full functionality while removing color formatting

- **Improved VPN Error Detection**: Better user experience for connection failures
  - Detects DNS resolution failures that indicate VPN disconnection
  - Provides helpful error messages suggesting VPN connection check
  - Graceful handling of network connectivity issues

### Changed
- **Command Line Interface**: Updated option shortcuts for consistency
  - Changed `--no-agg` shorthand from `-n` to `-A` for better mnemonics
  - Maintains backward compatibility with long form `--no-agg`
  - Improved help documentation with clearer option descriptions

- **Output Structure**: Enhanced JSON/YAML organization
  - JSON and YAML outputs now use environment names as root keys instead of arrays
  - Provides more intuitive data structure for programmatic consumption
  - Maintains compatibility with existing parsing while improving usability

### Fixed
- **Output Aggregation**: Resolved format conversion issues
  - Fixed aggregated output being empty when format options were specified
  - Corrected method visibility for output file operations
  - Improved temporary file handling to prevent format conflicts
  - Enhanced error handling for edge cases in format conversion

## [1.3.0] - 2025-01-05log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-09-29

### Added
- **Lotus Ping Functionality**: Prevents lotus autodownload errors during execution
  - Pre-pings lotus for each unique space/region combination before parallel execution
  - Thread-safe ping caching using mutex synchronization to avoid duplicate pings
  - Graceful error handling with warnings for failed pings
  - Verbose output shows ping status and timing for debugging

- **Cache-Aware Ping Optimization**: Intelligent ping strategy based on cache status
  - Only pings lotus when database URLs are not cached for that environment
  - Significantly reduces unnecessary lotus calls for cached environments
  - Maintains reliability while optimizing performance
  - Verbose output distinguishes between "cached - no lotus ping needed" and "not cached - will need lotus ping"

- **Pre-Ping Strategy**: Separates ping phase from execution phase
  - Analyzes all environments in group operation before starting parallel execution
  - Pings required space/region combinations upfront to establish sessions
  - Ensures parallel threads can execute without ping delays or conflicts
  - Maintains true parallel performance while preventing autodownload issues

### Fixed
- **Thread-Safe Parallel Execution**: Restored full parallel performance
  - Fixed thread-unsafe Set operations that were causing sequential execution instead of parallel
  - Replaced class variables with thread-safe class instance variables
  - Added proper mutex synchronization for shared ping cache state
  - Parallel execution timing restored (0.8s vs 16s sequential)

- **Code Quality Improvements**: Enhanced maintainability and Ruby best practices
  - Refactored OutputAggregator with SOLID design principles
  - Created dedicated DataExtractor class for separation of concerns
  - Replaced class variables (@@) with class instance variables (@) for thread safety
  - Added frozen string literal comments to all spec files
  - Cleaned up empty test files and fixed file permissions

### Performance
- **Optimized Group Operations**: Significant performance improvements for group queries
  - True parallel execution restored with proper thread safety
  - Smart ping optimization reduces lotus overhead
  - Cache-aware strategy minimizes unnecessary operations
  - Pre-ping phase eliminates delays during parallel execution

## [1.2.2] - 2025-01-01

### Added
- **Cache Encryption**: AES-256-GCM encryption for filesystem cache security
  - Database URLs stored in filesystem cache are now encrypted when `LSQL_CACHE_KEY` environment variable is set
  - Uses AES-256-GCM with unique initialization vector (IV) per cache entry for maximum security
  - Encryption key is hashed with SHA-256 to ensure consistent 32-byte key length
  - Graceful fallback to unencrypted cache when encryption key is not available
  - Redis cache remains unencrypted (Redis handles its own security)
  - Cache stats display shows encryption status: "Enabled" or "Disabled (set LSQL_CACHE_KEY)"

- **Configurable Cache Directory**: Filesystem cache directory is now configurable
  - Default location moved from `~/.lsql_cache` to `~/.lsql/cache` (co-located with config)
  - Configurable via `cache.directory` in config file or `LSQL_CACHE_DIR` environment variable
  - Automatic migration from legacy location with user notification
  - Cache stats display shows actual cache directory location

### Changed
- **Cache Directory Location**: Default filesystem cache moved to `~/.lsql/cache`
  - Provides better organization alongside configuration file in `~/.lsql/` directory
  - Automatic migration preserves existing cache entries
  - Legacy directory is cleaned up after successful migration

### Security
- **Enhanced Cache Security**: Database connection strings are now protected at rest in filesystem cache

## [1.2.1] - 2025-07-24

### Added
- **SSO Pre-authentication**: Automatic Lotus SSO session establishment before parallel execution
  - Uses simple `lotus ping` command to prevent multiple SSO authentication prompts during parallel group operations
  - Establishes session that works for all parallel threads without requiring environment-specific arguments
  - Includes graceful error handling and informative messaging

### Fixed
- **Column Alignment**: Improved table formatting in aggregated group output
  - Changed "environment" header to "env" for better space usage
  - Fixed column width calculation to ensure proper alignment
  - Better separator line detection and formatting

## [1.2.0] - 2025-07-24

### Added
- **GitHub Packages Publishing**: Automated gem publishing to GitHub Packages
  - Workflow automatically publishes new versions on release creation
  - Users can install without requiring RubyGems.org account
  - Includes setup script (`setup_github_packages.sh`) for easy configuration
- **Quiet Mode**: New `-q/--quiet` option to suppress execution summary and output headers
  - Reduces output to just the query results for cleaner automation and scripting
  - Suppresses "AGGREGATED OUTPUT" headers and "EXECUTION SUMMARY" sections
  - Maintains all functionality while providing minimal output

### Fixed
- **Column Alignment**: Improved table formatting in aggregated group output
  - Fixed regex pattern for detecting table separator lines
  - Better handling of psql table delimiters with proper `|` character detection
  - Consistent column alignment across multiple environment outputs
- **Ruby 3.1 Compatibility**: Fixed CI failures and compatibility issues
- **Code Quality**: Resolved all RuboCop style violations across codebase

### Changed
- **Execution Summary Format**: Successful environments now displayed on a single comma-separated line
  - Before: Each environment listed on separate lines with bullet points
  - After: All successful environments on one line (e.g., "staging, staging-s2, staging-s3")
  - Failed environments still display individually with error messages for better debugging

## [1.1.2] - 2025-07-24

### Added
- **Quiet Mode**: New `-q/--quiet` option to suppress execution summary and output headers
  - Reduces output to just the query results for cleaner automation and scripting
  - Suppresses "AGGREGATED OUTPUT" headers and "EXECUTION SUMMARY" sections
  - Maintains all functionality while providing minimal output

### Changed
- **Execution Summary Format**: Successful environments now displayed on a single comma-separated line
  - Before: Each environment listed on separate lines with bullet points
  - After: All successful environments on one line (e.g., "staging, staging-s2, staging-s3")
  - Failed environments still display individually with error messages for better debugging

## [1.1.1] - 2025-01-24

### Fixed
- Removed explicit optparse dependency to fix Ruby 3.1 compatibility issues
- Relaxed version constraints for redis, moneta, and concurrent-ruby dependencies for better compatibility across Ruby versions

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
