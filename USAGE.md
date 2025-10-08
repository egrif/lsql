# LSQL Usage Guide

This document provides comprehensive usage examples and advanced scenarios for LSQL.

## Table of Contents

- [Basic Operations](#basic-operations)
- [Environment Groups](#environment-groups)
- [Parallel Execution](#parallel-execution)
- [Output Formats](#output-formats)
- [Output Management](#output-management)
- [Quiet Mode](#quiet-mode)
- [Database Replicas](#database-replicas)
- [Cache Management](#cache-management)
- [Configuration](#configuration)
- [Advanced Scenarios](#advanced-scenarios)
- [Automation and Scripting](#automation-and-scripting)
- [Troubleshooting](#troubleshooting)

## Basic Operations

### Interactive Sessions

Start an interactive psql session for a single environment:

```bash
# Connect to development environment
lsql -e dev01

# Connect to production with color-coded prompt
lsql -e prod01

# Connect without color codes (for scripts or terminals without color support)
lsql -e prod01 -C

# Connect to specific region and application
lsql -e dev01 -r euc1 -a myapp
```

### Running SQL Commands

Execute SQL statements directly from the command line:

```bash
# Simple query
lsql "SELECT count(*) FROM users" -e prod01

# More complex query with formatting
lsql "SELECT id, name, email FROM users WHERE active = true LIMIT 10" -e staging

# Query with environment variables
lsql "SELECT * FROM orders WHERE created_at > '2024-01-01'" -e prod01

# Multi-line query (use quotes)
lsql "SELECT 
  u.name, 
  COUNT(o.id) as order_count 
FROM users u 
LEFT JOIN orders o ON u.id = o.user_id 
GROUP BY u.name 
ORDER BY order_count DESC 
LIMIT 5" -e prod01
```

### Running SQL Files

Execute SQL statements from files:

```bash
# Run a simple SQL file
lsql query.sql -e staging

# Run with output to file
lsql complex_analysis.sql -e prod01 -o analysis_results.txt

# Run with custom region and application
lsql report.sql -e staging -r use1 -a greenhouse -o report.csv
```

## Multiple Environments (À La Carte)

Execute commands against multiple specific environments with custom configurations:

### Basic Multiple Environment Usage

```bash
# Simple multiple environments
lsql "SELECT count(*) FROM users" -e "prod01,dev02,staging03"

# With custom space and region per environment  
lsql "SELECT * FROM system_status" -e "prod01:prod:use1,dev02:dev:euc1,staging03:prod:apse2"

# Mix of specified and default configurations
lsql "SELECT count(*) FROM orders" -e "prod01:prod,dev02,staging03:prod" -s dev -r use1
```

### Format Specification

Environment specification format: `ENV[:SPACE[:REGION]]`

- **ENV** (required): Environment name
- **SPACE** (optional): Environment space (`prod`, `dev`, etc.)
- **REGION** (optional): Environment region (`use1`, `euc1`, `apse2`)

### Precedence Rules

When space or region are omitted, values are determined by:

1. **Per-environment specification**: `prod01:prod:use1`  
2. **CLI flags**: `-s prod -r use1`
3. **Environment-based defaults**: 
   - Space: `prod` for prod/staging environments, `dev` for others
   - Region: `apse2` for 2XX environments, `euc1` for 1XX, `use1` for others
4. **Config file defaults**

### Examples with Defaults

```bash
# Using CLI flags as defaults for unspecified values
lsql "SELECT count(*) FROM users" -e "prod01,dev02:dev,staging03" -s prod -r euc1
# Result:
#   prod01 -> space: prod, region: euc1 (from CLI)  
#   dev02 -> space: dev, region: euc1 (dev specified, region from CLI)
#   staging03 -> space: prod, region: euc1 (from CLI)

# Environment-based defaults when no CLI flags provided
lsql "SELECT * FROM logs" -e "prod01,dev99,staging-s101"
# Result:
#   prod01 -> space: prod, region: use1 (prod env defaults)
#   dev99 -> space: dev, region: use1 (non-prod env defaults)  
#   staging-s101 -> space: prod, region: euc1 (staging env, 1XX region)
```

### Parallel Execution and Aggregation

Multiple environments support the same options as groups:

```bash
# Parallel execution with multiple environments
lsql "SELECT count(*) FROM users" -e "prod01,prod02,prod03" -p 3

# Disable output aggregation  
lsql "SELECT * FROM system_info" -e "prod01:prod:use1,dev02:dev:euc1" -A

# Quiet mode for automation
lsql "SELECT count(*) FROM orders" -e "prod01,dev02" -q

# Output to files
lsql report.sql -e "prod01,staging02" -o results -A  # Creates separate files per environment
```

## Environment Groups

### Listing Groups

```bash
# List all available groups
lsql -g list

# Example output:
# Available groups:
#   - staging (3 environments): staging, staging-s2, staging-s3
#   - production (5 environments): prod, prod-s2, prod-s3, prod-s4, prod-s5
#   - us-prod (3 environments): prod, prod-s2, prod-s3
```

### Basic Group Operations

```bash
# Run query on all staging environments
lsql "SELECT count(*) FROM users" -g staging

# Run query on production group
lsql "SELECT count(*) FROM orders" -g production

# Run SQL file on group
lsql monthly_report.sql -g us-prod
```

### Group Operations with Options

```bash
# Verbose group execution (see progress)
lsql "SELECT count(*) FROM products" -g staging -v

# Quiet group execution (clean output)
lsql "SELECT count(*) FROM users" -g staging -q

# No aggregation (separate results per environment)  
lsql "SELECT * FROM system_status" -g staging -A

# Group execution with output file
lsql "SELECT * FROM user_analytics" -g production -o analytics.txt
```

## Parallel Execution

### Auto-Detection

```bash
# Use all available CPU cores
lsql "SELECT count(*) FROM large_table" -g production -p

# Auto-detect with verbose output
lsql "SELECT * FROM complex_view" -g staging -p -v
```

### Custom Thread Count

```bash
# Use 4 threads
lsql "SELECT count(*) FROM orders" -g production -p 4

# Use 8 threads for large operations
lsql "SELECT * FROM analytics_data" -g all-environments -p 8
```

### Disabling Parallel Execution

Force sequential execution instead of default parallel execution:

```bash
# Disable parallel execution
lsql "SELECT * FROM sensitive_data" -g staging -P

# Disable parallel with verbose output
lsql "SELECT count(*) FROM users" -g production -P -v
```

### Parallel with Other Options

# Conservative threading for sensitive operations
lsql "SELECT count(*) FROM financial_data" -g production -p 2
```

### Parallel with Other Options

```bash
# Parallel + quiet mode for clean automation
lsql "SELECT count(*) FROM users" -g staging -p 4 -q

# Parallel + verbose for detailed monitoring
lsql "SELECT * FROM large_dataset" -g production -p 6 -v

# Parallel + no aggregation + output files
lsql report.sql -g staging -p 4 -A -o results

# Parallel + specific output format
lsql "SELECT id, name FROM users" -g staging -p -f csv -o users.csv
```

## Output Formats

### Table Format (Default)

```bash
lsql "SELECT id, name FROM users LIMIT 3" -g staging
```

Output:
```
env      | id  | name
---------+-----+----------
staging  | 101 | Alice
staging  | 102 | Bob  
staging-s2| 201| Charlie
```

### CSV Format

```bash
# CSV output to stdout
lsql "SELECT id, name, email FROM users LIMIT 5" -g staging -f csv

# CSV output to file
lsql "SELECT * FROM orders" -g production -f csv -o orders.csv
```

### JSON Format

```bash
# JSON output
lsql "SELECT id, name FROM users LIMIT 2" -g staging -f json

# Pretty JSON to file
lsql "SELECT * FROM user_preferences" -e prod01 -f json -o preferences.json
```

Example JSON output:
```json
{
  "staging": [
    {"id": "101", "name": "Alice"},
    {"id": "102", "name": "Bob"}
  ],
  "staging-s2": [
    {"id": "201", "name": "Charlie"}
  ]
}
```

### YAML Format

```bash
# YAML output
lsql "SELECT id, name FROM users LIMIT 2" -g staging -f yaml

# YAML to file  
lsql "SELECT * FROM configuration" -e staging -f yaml -o config.yml
```

### Tab-Separated Format

```bash
# Tab-separated output for data processing
lsql "SELECT id, name, created_at FROM users" -g staging -f txt

# Tab-separated to file for importing
lsql "SELECT * FROM export_data" -g production -f txt -o export.tsv
```

## Output Management

### Automatic Output Files

```bash
# Auto-generate filename
lsql "SELECT * FROM users" -g staging -o

# Results in files like: staging_output, staging-s2_output, etc.
```

### Custom Output Files

```bash
# Single aggregated output file
lsql "SELECT count(*) FROM orders" -g production -o order_counts.txt

# Environment-specific output files (with -A flag)
lsql "SELECT * FROM logs" -g staging -A -o logs
# Results in: logs_staging.txt, logs_staging-s2.txt, etc.
```

### Output with Different Formats

```bash
# JSON export for each environment
lsql "SELECT * FROM user_data" -g staging -A -f json -o user_data
# Results in: user_data_staging.json, user_data_staging-s2.json

# CSV export aggregated
lsql "SELECT id, name, email FROM users" -g production -f csv -o all_users.csv
```

## Quiet Mode

### Clean Output for Automation

Normal output includes headers and summaries:
```bash
lsql "SELECT count(*) FROM users" -g staging
```

Output:
```
============================================================
AGGREGATED OUTPUT  
============================================================
env      | count
---------|-------
staging  | 1500
staging-s2| 1600
============================================================
EXECUTION SUMMARY
============================================================
✓ Successful: 2
Total environments processed: 2
```

Quiet mode provides clean results only:
```bash
lsql "SELECT count(*) FROM users" -g staging -q
```

Output:
```
env      | count
---------|-------
staging  | 1500
staging-s2| 1600
```

### Quiet Mode Examples

```bash
# Save clean results to file
lsql "SELECT id, name FROM users" -g staging -q > users.csv

# Use in scripts
COUNT=$(lsql "SELECT count(*) FROM orders" -g production -q | tail -n +2 | awk '{sum += $3} END {print sum}')

# Pipe to other commands
lsql "SELECT email FROM users WHERE active = true" -g staging -q | grep "@company.com"

# Parallel execution with quiet output
lsql "SELECT * FROM large_table" -g production -p 4 -q > results.txt
```

## Database Replicas

### Read-Only Replicas

```bash
# Connect to read-only replica
lsql "SELECT count(*) FROM users" -e prod01 -m ro

# Read-only replica for heavy analytics
lsql analytics_query.sql -e prod01 -m ro -o analytics.txt

# Group operation on read-only replicas
lsql "SELECT * FROM large_dataset" -g production -m ro -p 4
```

### Secondary Replicas

```bash
# Use secondary replica
lsql "SELECT * FROM historical_data" -e prod01 -m secondary

# Secondary replica for backup verification
lsql backup_verification.sql -e prod01 -m secondary
```

### Tertiary and Custom Replicas

```bash
# Use tertiary replica
lsql "SELECT count(*) FROM archive_data" -e prod01 -m tertiary

# Custom replica name
lsql "SELECT * FROM special_data" -e prod01 -m analytics-replica
```

## Cache Management

### Cache Statistics

```bash
# View cache statistics
lsql --cache-stats
```

Example output:
```
============================================================
CACHE STATISTICS
============================================================
Cache Type: File-based
Directory: /Users/username/.lsql/cache
Encryption: Enabled
Entries: 15
TTL: 10 minutes  
Prefix: myteam
Total Size: 3.2 KB
Oldest Entry: 8 minutes ago
Newest Entry: 30 seconds ago
```

### Custom Cache Settings

```bash
# Custom cache prefix for team isolation
lsql "SELECT 1" -e dev01 --cache-prefix backend-team

# Custom TTL for long-running operations
lsql "SELECT count(*) FROM users" -g staging --cache-ttl 60

# Both custom prefix and TTL
lsql analytics.sql -g production --cache-prefix analytics --cache-ttl 30
```

### Cache Management

```bash
# Clear all cache entries
lsql --clear-cache

# Clear cache with specific prefix
lsql --cache-prefix backend-team --clear-cache

# Clear cache and run query
lsql "SELECT count(*) FROM fresh_data" -g staging --clear-cache

# Check cache stats after clearing
lsql --clear-cache && lsql --cache-stats
```

### Cache Encryption

```bash
# Enable cache encryption
export LSQL_CACHE_KEY="your-secret-encryption-key-32-chars"

# Verify encryption is enabled
lsql --cache-stats
# Output shows: Encryption: Enabled

# Disable encryption
unset LSQL_CACHE_KEY
lsql --cache-stats  
# Output shows: Encryption: Disabled (set LSQL_CACHE_KEY)
```

## Configuration

### Viewing Configuration

```bash
# Show current configuration
lsql --show-config
```

Example output:
```
============================================================
LSQL CONFIGURATION
============================================================
Configuration File: /Users/username/.lsql/settings.yml

Cache Settings:
  Prefix: myteam (from config file)
  TTL: 15 minutes (from config file)  
  Directory: /Users/username/.lsql/cache (from config file)

Available Groups:
  - staging (3 environments)
  - production (5 environments)
  - us-prod (3 environments)

Priority Information:
  CLI arguments > config file > environment variables > defaults
```

### Configuration Initialization

```bash
# Create default configuration file
lsql --init-config

# Initialize and then customize
lsql --init-config
# Edit ~/.lsql/settings.yml with your preferences
lsql --show-config  # Verify changes
```

### Configuration Testing

```bash
# Test configuration with different cache settings
lsql "SELECT 1" -e dev01 --cache-prefix test --cache-ttl 5 --show-config

# Verify group configuration
lsql -g list --show-config
```

## Advanced Scenarios

### Complex Analytics Workflows

```bash
# Step 1: Clear cache for fresh data
lsql --clear-cache

# Step 2: Run analytics on all production environments in parallel
lsql analytics_query.sql -g production -p 6 -f json -o analytics_results.json

# Step 3: Generate summary report
lsql summary_query.sql -g production -q > summary.txt

# Step 4: Export user data for further processing
lsql "SELECT id, name, email, created_at FROM users" -g production -f csv -q > users_export.csv
```

### Multi-Environment Comparison

```bash
# Compare user counts across environments
lsql "SELECT 
  '$(hostname)' as environment,
  count(*) as user_count,
  count(CASE WHEN active = true THEN 1 END) as active_users,
  count(CASE WHEN created_at > NOW() - INTERVAL '30 days' THEN 1 END) as recent_users
FROM users" -g production -v

# Compare database sizes
lsql "SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10" -g production -f csv -o db_sizes.csv
```

### Performance Monitoring

```bash
# Monitor query performance across environments
lsql "SELECT 
  query,
  calls,
  total_time,
  mean_time,
  stddev_time
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 20" -g production -f json -o performance_stats.json

# Check connection counts
lsql "SELECT 
  datname,
  numbackends,
  xact_commit,
  xact_rollback
FROM pg_stat_database 
WHERE datname NOT IN ('template0', 'template1', 'postgres')" -g production -p 4
```

### Data Export and Migration

```bash
# Export all user data in parallel
lsql "COPY (SELECT * FROM users) TO STDOUT WITH CSV HEADER" -g production -p 4 -q -o users_export

# Export specific date ranges
lsql "SELECT * FROM orders WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01'" -g production -f csv -o january_orders.csv

# Export with compression (using shell redirection)
lsql large_export_query.sql -g production -q | gzip > export.csv.gz
```

## Automation and Scripting

### Cron Jobs

```bash
# Daily user count monitoring (add to crontab)
0 6 * * * /usr/local/bin/lsql "SELECT count(*) FROM users" -g production -q >> /var/log/user_counts.log

# Weekly database size report
0 0 * * 0 /usr/local/bin/lsql db_size_report.sql -g production -f csv -o /reports/weekly_db_sizes.csv
```

### Shell Scripts

```bash
#!/bin/bash
# health_check.sh

echo "Starting database health check..."

# Check user counts
echo "User counts by environment:"
lsql "SELECT count(*) as user_count FROM users" -g production -q

# Check recent activity
echo "Recent activity (last 24h):"
lsql "SELECT count(*) FROM orders WHERE created_at > NOW() - INTERVAL '1 day'" -g production -q

# Check for any errors
echo "Recent errors:"
lsql "SELECT count(*) FROM error_logs WHERE created_at > NOW() - INTERVAL '1 hour'" -g production -q

echo "Health check complete."
```

### Monitoring Scripts

```bash
#!/bin/bash
# monitor_performance.sh

# Set cache encryption
export LSQL_CACHE_KEY="monitoring-key-32-characters-long"

# Clear old cache
lsql --cache-prefix monitoring --clear-cache

# Collect performance metrics
lsql "SELECT 
  NOW() as timestamp,
  (SELECT count(*) FROM users) as total_users,
  (SELECT count(*) FROM orders WHERE created_at > NOW() - INTERVAL '1 hour') as recent_orders,
  (SELECT avg(response_time) FROM api_logs WHERE created_at > NOW() - INTERVAL '5 minutes') as avg_response_time
" -g production --cache-prefix monitoring -f json -o "metrics_$(date +%Y%m%d_%H%M%S).json"
```

### Data Pipeline Integration

```bash
#!/bin/bash
# data_pipeline.sh

# Extract data from production
lsql extract_query.sql -g production -f csv -q > raw_data.csv

# Process the data (example with awk)
awk -F',' 'NR>1 {sum += $3} END {print "Total: " sum}' raw_data.csv

# Load processed data back (example)
lsql "COPY processed_data FROM '/path/to/processed_data.csv' WITH CSV HEADER" -e analytics-db
```

## Troubleshooting

### Connection Issues

```bash
# Test basic connectivity
lsql "SELECT 1" -e dev01 -v

# Clear cache if having connection issues
lsql --clear-cache
lsql "SELECT 1" -e dev01

# Test different regions
lsql "SELECT 1" -e dev01 -r use1
lsql "SELECT 1" -e dev01 -r euc1
```

### Cache Issues

```bash
# Check cache statistics
lsql --cache-stats

# Clear specific prefix
lsql --cache-prefix problematic-prefix --clear-cache

# Test without cache
lsql "SELECT 1" -e dev01 --cache-ttl 0
```

### Performance Issues

```bash
# Use fewer parallel threads
lsql long_query.sql -g large-group -p 2

# Use read-only replicas for heavy queries
lsql analytics.sql -g production -m ro -p 4

# Break large operations into smaller chunks
lsql "SELECT * FROM large_table LIMIT 1000" -g production -q
```

### Authentication Issues

```bash
# Check if lotus CLI is working
lotus ping

# Clear and re-establish authentication
lsql --clear-cache
lsql "SELECT 1" -e dev01 -v  # Will re-authenticate
```

### Output Issues

```bash
# Test different output formats
lsql "SELECT 1 as test" -e dev01 -f csv
lsql "SELECT 1 as test" -e dev01 -f json
lsql "SELECT 1 as test" -e dev01 -f yaml

# Check file permissions for output
lsql "SELECT 1" -e dev01 -o /tmp/test.txt
ls -la /tmp/test.txt
```

### Group Configuration Issues

```bash
# List available groups
lsql -g list

# Check configuration
lsql --show-config

# Test individual environments in a group
lsql "SELECT 1" -e staging    # Test first environment
lsql "SELECT 1" -e staging-s2 # Test second environment
```

This comprehensive usage guide covers all major features and scenarios for LSQL. For additional help, use `lsql --help` or refer to the project documentation.