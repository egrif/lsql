## Output Format

Aggregated output aligns columns and uses `env` as the prefix:

# LSQL

A powerful command-line SQL tool for Lotus environments with support for parallel execution, group operations, and intelligent caching.

## Features

- 🚀 **Parallel Execution**: Run queries across multiple environments concurrently with auto-detection or custom thread counts
- 🎯 **Environment Groups**: Execute queries on predefined environment groups with unified configuration
- ⚡ **Intelligent Caching**: Redis and file-based caching with configurable TTL and automatic cache management
- 🔒 **Encrypted Filesystem Cache**: AES-256-GCM encryption for cached database URLs with `LSQL_CACHE_KEY`
- 🗄️ **Configurable Cache Directory**: Customizable cache location via config file or `LSQL_CACHE_DIR` environment variable
- 🔧 **Unified Configuration**: Single `~/.lsql/config.yml` file for all settings, groups, and preferences
- 📊 **Real-time Progress Tracking**: Progress indicators, spinners, and comprehensive execution summaries
- 🔄 **Multiple Database Replicas**: Support for read-only, secondary, tertiary, and custom database replicas
- 📁 **Advanced Output Management**: Aggregated or per-environment output files with perfect column alignment
- 📋 **Multiple Output Formats**: Support for table, CSV, JSON, YAML, and tab-separated formats
- 🤫 **Quiet Mode**: Clean output without headers or summaries for automation and scripting
- 🔑 **SSO Pre-authentication**: Automatic Lotus SSO session establishment before parallel execution
- 🎨 **Color-coded Interface**: Environment-aware color coding (red for production, green for development)
- 🔍 **Environment Auto-detection**: Automatic region and space detection with override capabilities
- 📈 **Cache Statistics**: Detailed cache usage statistics and TTL information
- 🧹 **Cache Management**: Selective cache clearing with prefix support and automatic cleanup
- 🔧 **Configuration Management**: Easy configuration viewing, initialization, and validation
- 🏗️ **Modular Architecture**: Clean separation of concerns with comprehensive error handling
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
2. `~/.lsql/settings.yml`
3. Default settings (built-in)
4. Environment variables (lowest)
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

4. **Run Query on Multiple Environments (À La Carte)**:
   ```bash
   # Multiple environments with custom space/region
   lsql "SELECT count(*) FROM users" -e "prod01:prod:use1,dev02:dev:euc1,staging03"
   
   # Use CLI flags as defaults for unspecified values
   lsql "SELECT count(*) FROM users" -e "prod01,dev02:dev,staging03" -s prod -r use1
   ```

5. **Run Query on Group with Parallel Execution**:
   ```bash
   lsql "SELECT count(*) FROM users" -g staging -p 4
   ```

6. **Get Clean Results for Automation**:
   ```bash
   lsql "SELECT count(*) FROM orders" -g staging -q
   ```

## Configuration

LSQL uses a unified configuration file at `~/.lsql/settings.yml`:

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
2. `~/.lsql/settings.yml`
3. Default settings (built-in)
4. Environment variables (lowest)

For comprehensive usage examples and advanced scenarios, see [USAGE.md](USAGE.md).

## Command-Line Options

| Option / Flag                | Description                                                                                  |
|------------------------------|----------------------------------------------------------------------------------------------|
| `-e ENV`                     | Target environment(s): single (`prod01`) or multiple (`prod01:prod:use1,dev02:dev:euc1`)    |
| `-g GROUP` / `--group GROUP` | Execute against environment group; use `list` to see available groups                        |
| `-A` / `--no-agg`            | Disable output aggregation for group operations                                              |
| `-C` / `--no-color`          | Disable color codes for interactive psql sessions                                            |
| `-p [THREADS]` / `--parallel [THREADS]` | Enable parallel execution; auto-detect cores or specify count                   |
| `-P` / `--no-parallel`       | Disable parallel execution for group operations                                              |
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
