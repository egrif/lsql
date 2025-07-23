# LSQL - Lotus SQL Client

A Ruby application for connecting to PostgreSQL databases using the Lotus secret management system.

## Features

- Interactive PostgreSQL sessions with environment-specific prompts
- Execute SQL commands directly from command line
- Run SQL files
- Output to files with automatic naming
- Support for read-only replicas
- Environment-based region and space detection
- Color-coded prompts (red for production, green for development)

## Installation

1. Clone or copy this application to your desired location
2. Install dependencies:
   ```bash
   bundle install
   ```

## Usage

The application provides the same functionality as the original `lsql.rb` script:

### Interactive Session
```bash
./bin/lsql -e dev01
```

### Execute SQL Command
```bash
./bin/lsql "SELECT * FROM users" -e prod01
```

### Execute SQL File
```bash
./bin/lsql query.sql -e staging -o results
```

### Using Read-Only Replicas
```bash
./bin/lsql -e prod01 -m ro          # Primary replica
./bin/lsql -e prod01 -m secondary   # Secondary replica
./bin/lsql -e prod01 -m tertiary    # Tertiary replica
```

### Custom Application and Region
```bash
./bin/lsql -e dev01 -r use1 -a customapp
```

## Options

- `-e ENV`: Environment (required)
- `-o [OUTPUT_FILE]`: Output file (optional, auto-generates if not specified)
- `-r REGION`: Region (optional, auto-detected from environment)
- `-a APPLICATION`: Application (optional, default: "greenhouse")
- `-s SPACE`: Space (optional, auto-detected from environment)
- `-m MODE`: Database connection mode (optional, default: "rw")
  - `rw`: Read-write access (primary database)
  - `ro`/`r1`/`primary`: Read-only access using primary replica
  - `r2`/`secondary`: Read-only access using secondary replica
  - `r3`/`tertiary`: Read-only access using tertiary replica
  - `<custom>`: Uses custom replica name

## Architecture

The application is organized into the following modules:

- `Lsql::CommandLineParser`: Handles command-line argument parsing
- `Lsql::OutputFileManager`: Manages output file configuration and setup
- `Lsql::EnvironmentManager`: Handles environment and region determination
- `Lsql::DatabaseConnector`: Manages database URL retrieval and transformation
- `Lsql::SqlExecutor`: Handles SQL execution (interactive, file, command)
- `Lsql::Application`: Main application class that coordinates all components

## Requirements

- Ruby 2.7 or later
- PostgreSQL client (`psql`)
- Lotus CLI tool for secret management
- Access to the configured environments

## Development

The application includes a Gemfile for dependency management and can be extended with additional features as needed.

### Running Tests

```bash
bundle exec rspec
```

### Code Style

```bash
bundle exec rubocop
```
