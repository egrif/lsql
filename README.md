## Output Format

Aggregated output aligns columns and uses `env` as the prefix:

```
env      | count
---------|------
prod     | 358
prod-s2  | 358
...
```
## Parallel Execution

LSQL supports concurrent execution across multiple environments:

- **Auto CPU Detection**: Use `-p` to automatically detect CPU cores
- **Custom Thread Count**: Use `-p 4` to specify exact thread count
- **Progress Tracking**: Real-time progress with spinners and counters
- **Error Isolation**: Individual environment failures don't stop other executions
- **Performance**: Dramatically faster execution for large environment groups
- **SSO Optimization**: Automatically establishes SSO session before parallel execution to prevent multiple authentication prompts
## Cache Encryption

Enable cache encryption by setting the encryption key:
```bash
export LSQL_CACHE_KEY="your-secret-encryption-key"
lsql --cache-stats
# Output shows: Encryption: Enabled
```
Without the encryption key:
```bash
unset LSQL_CACHE_KEY
lsql --cache-stats  
# Output shows: Encryption: Disabled (set LSQL_CACHE_KEY)
```
## Configuration Priority

1. CLI arguments (highest)
2. `~/.lsql/config.yml`
3. Environment variables
4. Built-in defaults (lowest)
## Environment Variables

| Variable           | Description                                      |
|--------------------|--------------------------------------------------|
| `LSQL_CACHE_KEY`   | Encryption key for filesystem cache              |
| `LSQL_CACHE_DIR`   | Custom cache directory location                  |
| `LSQL_CACHE_PREFIX`| Default cache key prefix                         |
| `LSQL_CACHE_TTL`   | Default cache TTL in minutes                     |
| `REDIS_URL`        | Redis connection URL for caching                 |
# LSQL

A powerful command-line SQL tool for Lotus environments with support for parallel execution, group operations, and intelligent caching.

## Features

- 🚀 **Parallel Execution**: Run queries across multiple environments concurrently
- 🎯 **Group Operations**: Execute queries on predefined environment groups
- ⚡ **Intelligent Caching**: Redis and file-based caching with configurable TTL
- �️ **Encrypted Filesystem Cache**: AES-256-GCM encryption for cached database URLs (`LSQL_CACHE_KEY`)
- 🗄️ **Configurable Cache Directory**: Set via config file or `LSQL_CACHE_DIR`
- �🔧 **Unified Configuration**: Single config file for all settings and groups
- 📊 **Progress Tracking**: Real-time progress indicators and execution summaries
- 🔄 **Multiple Replicas**: Support for read-only, secondary, and custom replicas
- 📁 **Output Management**: Aggregated or per-environment output files, with aligned columns and `env` prefix
- 🤫 **Quiet Mode**: Suppress headers and summaries for clean automation output
- 🔑 **SSO Pre-authentication**: Lotus SSO session established before parallel execution
## Installation

### From GitHub Packages (Recommended)
```bash
# If the `gem install` command below doesn't find the gem, then Configure gem source
gem sources --add https://GITHUB_USERNAME:TOKEN@rubygems.pkg.github.com/egrif

# Install the gem
gem install lsql
```
or
```bash
# Configure bundler to use GitHub Packages
bundle config set --global https://rubygems.pkg.github.com/egrif USERNAME:TOKEN

# Install the gem
gem install lsql --source "https://rubygems.pkg.github.com/egrif"
```

### From GitHub Repository
```bash
# Install directly from GitHub
gem install specific_install
gem specific_install https://github.com/egrif/lsql.git

# Or using bundler in a Gemfile
# gem 'lsql', git: 'https://github.com/egrif/lsql.git'
```

### From GitHub Releases
```bash
# Download the latest release
wget https://github.com/egrif/lsql/releases/latest/download/lsql-1.1.2.gem
gem install lsql-1.1.2.gem
```

### From Source
```bash
git clone https://github.com/egrif/lsql.git
cd lsql
gem build lsql.gemspec
gem install ./lsql-1.1.2.gem
```

## Quick Start

1. **Initialize Configuration**:
   ```bash
   lsql --init-config
   ```

2. **List Available Groups**:
   ```bash
   lsql -g list
   ```

3. **Run a Query on Single Environment**:
   ```bash
   lsql "SELECT count(*) FROM users" -e dev01
   ```

4. **Run Query on Group with Parallel Execution**:
   ```bash
   lsql "SELECT count(*) FROM users" -g staging -p 4
   ```

5. **Get Clean Results for Automation**:
   ```bash
   lsql "SELECT count(*) FROM orders" -g staging -q
   ```

## Configuration

LSQL uses a unified configuration file at `~/.lsql/config.yml`:

```yaml
# Cache settings
cache:
  prefix: db_url
  ttl_minutes: 10

# Environment groups  
groups:
  staging:
    description: Staging environments
    environments:
      - staging
      - staging-s2
      - staging-s3
  
  production:
    description: Production environments
    environments:
      - prod
      - prod-s2
      - prod-s3
```

### Configuration Priority
1. CLI arguments (highest)
2. `~/.lsql/config.yml`
3. Environment variables
4. Built-in defaults (lowest)

## Usage Examples

### Basic Operations
```bash
# Interactive session
lsql -e dev01

# Execute SQL statement
lsql "SELECT * FROM users LIMIT 10" -e prod01

# Execute SQL file
lsql query.sql -e staging -o results.txt
```

### Group Operations
```bash
# List all groups
lsql -g list

# Run on all staging environments
lsql "SELECT count(*) FROM orders" -g staging

# Parallel execution with 4 threads
lsql "SELECT * FROM users" -g staging -p 4

# Verbose parallel execution
lsql "SELECT count(*) FROM products" -g staging -p 4 -v

# Quiet mode for clean output (no headers or summaries)
lsql "SELECT count(*) FROM users" -g staging -q

# No output aggregation (separate results)
lsql "SELECT count(*) FROM users" -g staging -n
```

### Advanced Options
```bash
# Custom cache settings
lsql "SELECT 1" -e dev01 --cache-prefix myteam --cache-ttl 30

# Different database replicas
lsql "SELECT count(*) FROM users" -e prod01 -m ro          # Read-only
lsql "SELECT count(*) FROM users" -e prod01 -m secondary   # Secondary replica

# Custom region/application
lsql "SELECT 1" -e dev01 -r euc1 -a myapp

# Quiet mode for automation/scripting
lsql "SELECT count(*) FROM users" -g staging -q > user_counts.txt
```

### Cache Management
```bash
# Show cache statistics
lsql --cache-stats

# Clear cache
lsql --clear-cache

# Clear cache with custom prefix
lsql --cache-prefix myteam --clear-cache
```

### Cache Encryption

For enhanced security, database URLs stored in the file cache can be encrypted using AES-256-GCM encryption:

```bash
# Enable cache encryption by setting the encryption key
export LSQL_CACHE_KEY="your-secret-encryption-key"

# Check encryption status
lsql --cache-stats
# Output shows: Encryption: Enabled

# Without encryption key
unset LSQL_CACHE_KEY
lsql --cache-stats  
# Output shows: Encryption: Disabled (set LSQL_CACHE_KEY)
```

**Cache Directory Configuration:**
- Default location: `~/.lsql/cache`
- Configurable via config file or `LSQL_CACHE_DIR` environment variable
- Automatic migration from legacy location (`~/.lsql_cache`)

**Security Notes:**
- Encryption only applies to file-based cache (not Redis)
- Redis cache doesn't need encryption (handled by Redis security)
- Uses AES-256-GCM with unique IV per entry for maximum security
- Key is hashed with SHA-256 to ensure consistent 32-byte encryption key

### Configuration Management
```bash
# Show current configuration
lsql --show-config

# Initialize with default config
lsql --init-config
```

## Command-Line Options

| Option / Flag                | Description                                                                                  |
|------------------------------|----------------------------------------------------------------------------------------------|
| `-e ENV`                     | Target environment (required unless using `-g`)                                              |
| `-g GROUP` / `--group GROUP` | Execute against environment group; use `list` to see available groups                        |
| `-n` / `--no-agg`            | Disable output aggregation for group operations                                              |
| `-p [THREADS]` / `--parallel [THREADS]` | Enable parallel execution; auto-detect cores or specify count                   |
| `-v` / `--verbose`           | Verbose output with detailed progress                                                        |
| `-q` / `--quiet`             | Quiet mode: suppress execution summary and output headers                                    |
| `-o [FILE]`                  | Output file (auto-generated if no filename provided)                                         |
| `-r REGION`                  | Override default region (use1/euc1/apse2)                                                    |
| `-a APP`                     | Override default application (default: greenhouse)                                           |
| `-s SPACE`                   | Override default space (prod/dev)                                                            |
| `-m MODE`                    | Database mode: rw/ro/secondary/tertiary/custom                                               |
| `--cache-prefix PREFIX`      | Custom cache key prefix                                                                      |
| `--cache-ttl MINUTES`        | Cache TTL in minutes                                                                         |
| `--cache-stats`              | Show cache statistics                                                                        |
| `--clear-cache`              | Clear database URL cache                                                                     |
| `--show-config`              | Display current configuration                                                                |
| `--init-config`              | Create default configuration file                                                            |
| `-h` / `--help`              | Show help message                                                                            |
| `--version`                  | Show version                                                                                 |

## Parallel Execution

LSQL supports concurrent execution across multiple environments:

- **Auto CPU Detection**: Use `-p` to automatically detect CPU cores
- **Custom Thread Count**: Use `-p 4` to specify exact thread count
- **Progress Tracking**: Real-time progress with spinners and counters
- **Error Isolation**: Individual environment failures don't stop other executions
- **Performance**: Dramatically faster execution for large environment groups
- **SSO Optimization**: Automatically establishes SSO session before parallel execution to prevent multiple authentication prompts

### Parallel Execution Examples
```bash
# Auto-detect CPU cores
lsql "SELECT count(*) FROM users" -g staging -p

# Use 8 threads
lsql "SELECT count(*) FROM orders" -g production -p 8

# Parallel with verbose output
lsql "SELECT count(*) FROM products" -g staging -p 4 -v

# Parallel with quiet mode (clean output for automation)
lsql "SELECT count(*) FROM users" -g staging -p 4 -q

# Parallel with separate output files
lsql query.sql -g staging -p 4 -n -o results
```

## Quiet Mode

The `--quiet` (or `-q`) option suppresses execution summaries and output headers, providing clean results perfect for automation and scripting:

### Normal Output
```
============================================================
AGGREGATED OUTPUT
============================================================
[Query results here]

============================================================
EXECUTION SUMMARY
============================================================
✓ Successful: 3
  staging, staging-s2, staging-s3

Total environments processed: 3
```

### Quiet Output
```
[Query results only - no headers or summaries]
```

### Quiet Mode Examples
```bash
# Save clean query results to file
lsql "SELECT id, name FROM users" -g staging -q > users.csv

# Use in scripts for automated reporting
COUNT=$(lsql "SELECT count(*) FROM orders" -g production -q)

# Chain with other commands
lsql "SELECT email FROM users WHERE active = true" -g staging -q | grep -E "@company\.com$"

# Combine with parallel execution for performance
lsql "SELECT * FROM large_table" -g staging -p 4 -q > results.txt
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `LSQL_CACHE_KEY` | Encryption key for filesystem cache security |
| `LSQL_CACHE_DIR` | Custom cache directory location |
| `LSQL_CACHE_PREFIX` | Default cache key prefix |
| `LSQL_CACHE_TTL` | Default cache TTL in minutes |
| `REDIS_URL` | Redis connection URL for caching |

## Development

### Running Tests
```bash
bundle install
bundle exec rspec
```

### Running Linter
```bash
bundle exec rubocop
```

### Building Gem
```bash
gem build lsql.gemspec
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Architecture

The application is organized into modular components:

### Core Modules
- `Lsql::CommandLineParser`: Command-line argument parsing and validation
- `Lsql::ConfigManager`: Unified configuration management and group handling
- `Lsql::OutputFileManager`: Output file configuration and management
- `Lsql::EnvironmentManager`: Environment and region detection
- `Lsql::DatabaseConnector`: Database URL retrieval and caching
- `Lsql::SqlExecutor`: SQL execution (interactive, file, command)
- `Lsql::GroupHandler`: Parallel execution for environment groups
- `Lsql::Application`: Main application orchestration

### Key Features
- **Unified Configuration**: Single `~/.lsql/config.yml` for all settings
- **Parallel Execution**: Concurrent processing with thread pools
- **Smart Caching**: Redis-based URL caching with TTL
- **Environment Groups**: Logical grouping of related environments
- **Color-coded Interface**: Red for production, green for development
- **Progress Tracking**: Real-time feedback for long-running operations

## Requirements

- Ruby 3.0 or later
- PostgreSQL client (`psql`)
- Lotus CLI tool for secret management
- Redis server (for caching)
- Access to configured environments

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Support

For issues, feature requests, or contributions, please visit the [GitHub repository](https://github.com/egrif/lsql).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
bundle exec rubocop
```
