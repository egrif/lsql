# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.11] - 2025-12-15

### Fixed
- **JSON/YAML Format Output**: Fixed empty array output for JSON and YAML formats
  - Changed psql options from `-t -A` to `-A -F '\t' -P footer=off` to include headers
  - Headers are now properly included in the output for correct parsing
  - Tab separator is explicitly set for consistent parsing
  - Footer is suppressed to avoid parsing issues
  - Both JSON and YAML formats now correctly display query results

## [1.7.10] - 2025-12-15

### Enhanced
- **Result Display**: Improved output for queries that return no data or status messages
  - Displays status messages (e.g., "UPDATE 3", "INSERT 0 1") instead of empty rows
  - Shows "(no data returned)" for empty result sets that aren't status messages
  - Correctly handles mixed output where some environments return data and others return status
  - Improves visibility of non-SELECT query results in group operations

## [1.7.9] - 2025-12-09

### Fixed
- **Error Display**: Fixed SQL errors being swallowed when running queries from input files
  - SQL errors, warnings, and notices are now always displayed to stderr
  - Added explicit error detection for ERROR:, FATAL:, and PANIC: messages
  - Exit with error code 1 when SQL errors are detected, even if psql returns success
  - Changed from `warn` to `$stderr.puts` for more reliable error output
  - Ensures all PostgreSQL messages are visible to users for better debugging

## [1.7.8] - 2025-11-26

### Added
- **Database Override**: Added `-d --database` argument to specify custom database name
  - Override database name in URL from lotus (e.g., `-d analytics_db`)
  - Works with all connection modes (rw, ro, r1, r2, r3, custom)
  - Preserves query parameters when overriding database name
  - Handles both `postgres://` and `postgresql://` URL formats
  - Added comprehensive test coverage for database URL parsing and override functionality

## [1.7.7] - 2025-10-30

### Fixed
- **Output Aggregator**: Fixed SELECT * queries showing no output when most environments have no rows
  - Extract columns from PostgreSQL headers even when no data rows exist
  - Store columns for each environment even when query returns no rows
  - Fix row parsing to handle trailing empty strings (NULL/empty columns)
  - Ensures all columns are displayed in aggregated output even when only one environment has data

## [1.7.6] - 2025-10-30

### Fixed
- **Group Handler Execution**: Fixed group operations failing with undefined method 'env' error
  - Convert environment strings to options objects before execution
  - Properly handle cluster detection for group environments (e.g., prod-s2, prod-s9)
  - Fixed parallel execution to work correctly with group environments containing dashes
  - All group execution methods now receive properly configured options objects

## [1.7.5] - 2025-10-30

### Added
- **Cluster Support**: Added cluster concept as replacement for SPACE and REGION
  - Cluster auto-detection: Environment values with dashes after `:` are treated as cluster (e.g., `prod:prod-use1-0`)
  - `--cluster` CLI flag: Explicitly specify cluster for environments that don't have it in the environment value
  - Cluster replaces space and region in lotus commands when specified
  - Format: `ENV:CLUSTER` where cluster contains dashes (e.g., `prod:prod-use1-0`)
  - Backward compatible: Existing `ENV:SPACE:REGION` format still works
  - Full integration with caching, parallel execution, and output aggregation

### Fixed
- **Database URL Validation**: Enhanced validation and auto-recovery for database URLs
  - Validates cached URLs are proper postgres:// or postgresql:// URLs before use
  - Automatically clears invalid cached URLs and fetches fresh ones
  - Prevents bad URLs from being cached (e.g., lotus installation messages)
  - Improved error messages showing exact lotus command and output for debugging
- **Lotus Output Parsing**: Robust parsing of lotus command output
  - Correctly extracts DATABASE_MAIN_URL even when lotus outputs installation messages
  - Handles multiple output formats (with `=` or `:` separator)
  - Better error handling with detailed diagnostic information

### Enhanced
- **Error Handling**: Improved error messages for database connection issues
  - Shows exact lotus command executed
  - Displays full stdout and stderr when URL extraction fails
  - Validates database URLs before caching to prevent corruption

## [1.7.4] - 2025-10-10

### Fixed
- **Interactive Session Output**: Completely removed debug output from interactive psql sessions
  - Eliminated "Connecting to: hostname" message that was still appearing in interactive mode
  - Interactive sessions now start cleanly without any debug noise
  - Maintains clean user experience for direct psql console usage

## [1.7.3] - 2025-10-10

### Enhanced
- **Code Quality & Architecture**: Comprehensive codebase improvements
  - Refactored large methods in `SqlExecutor` for better maintainability
  - Improved error handling consistency across all components
  - Enhanced temporary file management using Ruby's `Tempfile` class
  - Added comprehensive input validation and sanitization
  - Improved string building efficiency for frozen string literal compatibility

### Added
- **Configuration Validation**: Added robust validation for configuration files
  - Validates group structure and environment definitions
  - Checks cache settings including TTL values
  - Provides clear error messages for invalid configurations
- **Enhanced Documentation**: Improved inline code documentation
  - Added comprehensive method documentation with parameter types
  - Documented all supported environment variables
  - Enhanced error messages with contextual help
- **Security Improvements**: Enhanced credential handling and input sanitization
  - Sanitizes database URLs for safe logging (removes credentials)
  - Added SQL injection protection patterns
  - Improved command sanitization for shell execution

### Performance
- **Optimized String Operations**: Improved performance for large result sets
  - More efficient string concatenation using mutable strings
  - Reduced memory allocation in output aggregation
  - Better handling of large SQL result processing

### Developer Experience
- **Better Testing Infrastructure**: Enhanced test coverage and reliability
  - Added tests for error handling edge cases
  - Improved mock usage for database connections
  - Enhanced CI/CD pipeline reliability

## [1.7.2] - 2025-10-09

### Fixed
- **Interactive Session Output**: Removed debug output from interactive psql sessions
  - Eliminated "DEBUG: Raw prompt", "DEBUG: Sanitized prompt", and "DEBUG: psql command" messages
  - Interactive sessions now start cleanly without debugging noise
  - Maintains all functionality while providing clean user experience
- **String Mutation Error**: Fixed FrozenError in output aggregation for Ruby 2.7+
  - Updated OutputAggregator to use String.new for mutable string building
  - Resolves frozen_string_literal compatibility issues
  - Ensures proper functioning across all supported Ruby versions (2.7+)

### Enhanced
- **CI Compatibility**: Improved GitHub Actions workflow for multi-Ruby support
  - Added proper Bundler version pinning for Ruby 2.7 and 3.0 compatibility
  - Fixed workflow linting errors and environment variable handling
  - Maintains testing across Ruby 2.7, 3.0, 3.1, 3.2, and 3.3

## [1.7.0] - 2025-10-08

### Added
- **À La Carte Multiple Environments**: Execute SQL against multiple environments with custom configurations
  - Format: `ENV[:SPACE[:REGION]]` for per-environment space/region overrides
  - Example: `lsql "SELECT count(*) FROM users" -e "prod01:prod:use1,dev02:dev:euc1,staging03"`
  - Intelligent precedence system for space/region defaults
  - Full integration with existing parallel execution and output aggregation

### Enhanced
- **Environment Manager**: Completely refactored to handle both single and multiple environments
  - Support for precedence-based configuration resolution
  - Per-environment space and region overrides
  - Backward compatibility with existing single environment usage
- **Group Handler**: Updated to work seamlessly with pre-configured environment options
- **Output Aggregation**: Enhanced to properly display results from multiple environments
- **Documentation**: Comprehensive updates to README.md and USAGE.md with examples and precedence rules

### Fixed
- **Multiple Environment Output**: Resolved issue where multiple environment execution showed no output
- **OpenStruct Compatibility**: Fixed `undefined method 'include?'` error when executing across multiple environments

## [1.5.3] - 2025-10-08

### Added
- **Configurable Prompts**: Added comprehensive prompt configuration system
  - Configurable color schemes for production (red) and development (green) environments
  - Customizable prompt templates with variable substitution (`{color}`, `{env}`, `{mode}`, `{reset}`, etc.)
  - Smart environment detection based on configurable patterns
  - Full backward compatibility with existing `--no-color` functionality

### Changed
- **Configuration System**: Enhanced settings management
  - Changed configuration file extension from `.yaml` to `.yml` for consistency
  - Unified configuration system with default settings merging
  - Removed legacy `.lsql_groups.yml` file in favor of unified `~/.lsql/settings.yml`

### Fixed
- **Documentation**: Corrected command-line option references
  - Fixed incorrect `-n` flag references to correct `-A` for `--no-agg` option
  - Added missing `--no-color` (`-C`) and `--no-parallel` (`-P`) options to documentation
  - Updated all usage examples to use correct flag syntax

### Improved
- **User Experience**: Enhanced configuration template
  - Added comprehensive commented examples for all configuration options
  - Improved user configuration file with prompt customization examples
  - Better error messages and help text consistency

## [1.5.2] - 2025-10-07

### Fixed
- **Output Formatting**: Fixed column alignment in aggregated output
  - Resolved issue where columns were misaligned when displaying results from multiple environments
  - Column widths now properly calculated from all aggregated data rather than individual environment outputs
  - Ensures proper table formatting for group operations (`-g` flag) with multiple environments

## [1.5.1] - 2025-10-02

### Added
- **Ruby Compatibility**: Expanded Ruby version support
  - Now compatible with Ruby 2.7.0 and above (previously required Ruby 3.0+)
  - Added explicit OStruct dependency for better compatibility
  - Improved cross-version compatibility for wider deployment scenarios

### Changed
- **Dependencies**: Updated dependency constraints for better semantic versioning
  - Updated base64 and ostruct dependencies to use recommended version constraints
  - Improved dependency resolution across different Ruby versions

## [1.5.0] - 2025-09-30

### Added
- **Version Information Display**: New `--version` flag and version in help
  - Added `--version` flag to display current version information
  - Version number now prominently displayed in help banner
  - Follows standard CLI conventions for version reporting

- **Enhanced Parallel Execution Control**: Improved parallel execution options
  - Parallel execution now enabled by default for group operations (auto-detect CPU cores)
  - Added `-p [THREADS]` option to specify custom thread count or use auto-detection
  - Added `-P/--no-parallel` option to disable parallel execution entirely
  - Maintains backward compatibility while providing better performance defaults

### Changed
- **Default Behavior**: Group operations now use parallel execution by default
  - Automatic CPU core detection for optimal performance
  - Improved user experience with faster multi-environment queries
  - Sequential execution still available via `-P/--no-parallel` option

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
