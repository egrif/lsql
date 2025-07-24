# Group Handler Documentation

The LSQL tool now supports executing commands against groups of environments using the `-g` (or `--group`) option, with optional outp4. **Output Aggregation**: By default, group operations aggregate output. Use `-n` to disable aggregation and get separate outputs per environment.

5. **Verbose Output**: By default, group operations show simple progress dots. Use `-v` to enable detailed progress information per environment.

6. **Error Handling**: If any environment in the group fails, the operation will continue with the remaining environments. A summary will be displayed at the end showing which environments succeeded and which failed.aggregation for easier analysis.

## Output Aggregation

By default, when running commands against a group of environments, the output is aggregated:

1. **Column headers are shown only once** (from the first environment)
2. **Each data row is prefixed** with the environment name
3. **Results are combined** into a single, unified output

To disable aggregation and get separate output per environment (the traditional behavior), use the `--no-agg` (`-n`) option.

### Aggregated Output Example

```bash
lsql "SELECT current_database(), count(*) FROM users" -g staging
```

Output:
```
environment | current_database    | count 
------------ | ------------------- | -------
staging     | greenhouse_staging  |  1250
staging-s2  | greenhouse_staging  |  1248  
staging-s3  | greenhouse_staging  |  1252
```

### Non-Aggregated Output Example

```bash
lsql "SELECT current_database(), count(*) FROM users" -g staging -n
```

Output shows separate result sets for each environment, as before.

## Verbose Output Control

By default, group operations show minimal progress information to keep the output clean:

**Default (Non-Verbose) Mode:**
- Shows simple progress: `Progress: .... done`
- Only displays aggregated results at the end
- Minimal connection information

**Verbose Mode (`-v` flag):**
- Shows detailed progress per environment
- Displays connection information for each environment
- Shows success/failure status for each environment

### Verbose vs Non-Verbose Examples

```bash
# Non-verbose (default) - clean, minimal output
lsql "SELECT count(*) FROM users" -g staging

# Verbose - detailed progress information
lsql "SELECT count(*) FROM users" -g staging -v
```

## Quiet Mode

For automation and scripting scenarios, you can use the `--quiet` (or `-q`) option to suppress execution summaries and output headers:

### Normal Group Output
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

### Quiet Group Output
```
[Query results only - no headers, no execution summary]
```

### Quiet Mode Examples

```bash
# Clean output for automation
lsql "SELECT count(*) FROM users" -g staging -q

# Combine with other options
lsql "SELECT count(*) FROM orders" -g staging -p 4 -q > results.txt

# Perfect for scripting
COUNT=$(lsql "SELECT count(*) FROM users" -g staging -q)
echo "Total users across staging: $COUNT"
```

## Parallel Execution

LSQL supports parallel execution for group operations using the `-p` or `--parallel` option:

- **Auto CPU Detection**: Use `-p` to automatically use all available CPU cores
- **Custom Thread Count**: Use `-p 4` to specify exact number of threads
- **SSO Optimization**: Automatically establishes Lotus SSO session before parallel execution to prevent multiple authentication prompts
- **Progress Tracking**: Real-time progress indicators show completion status
- **Error Isolation**: Individual environment failures don't stop other executions

### SSO Authentication

When using parallel execution with Lotus environments, LSQL automatically:

1. **Pre-authenticates** with Lotus SSO using `lotus ping` before starting parallel jobs
2. **Establishes session** that is shared across all parallel threads  
3. **Prevents multiple SSO prompts** that would otherwise interrupt each parallel job
4. **Uses simple ping command** that requires no environment-specific arguments
5. **Gracefully handles** authentication failures with informative warnings

### Parallel Examples

```bash
# Auto-detect CPU cores with SSO pre-authentication
lsql "SELECT count(*) FROM users" -g staging -p

# Use 4 threads with verbose output
lsql "SELECT version()" -g production -p 4 -v

# Parallel execution with clean output for automation
lsql "SELECT current_timestamp" -g staging -p -q
```

**Note**: The first time you run a parallel group operation in a session, you'll see "Establishing SSO session..." in verbose mode as LSQL authenticates once for all subsequent parallel jobs.

## Configuration File

Groups are defined in a YAML configuration file named `.lsql_groups.yml`. The tool will search for this file starting from the current directory and moving up the directory tree until it finds one or reaches the root.

If no configuration file is found, a sample configuration will be created automatically.

### Configuration Format

```yaml
groups:
  group_name:
    description: "Description of the group"
    environments:
      - env1
      - env2
      - env3
```

### Example Configuration

```yaml
groups:
  staging:
    description: Staging environments
    environments:
      - staging
      - staging-s2
      - staging-s3
      - staging-s101
      - staging-s201
  all-prod:
    description: All production environments
    environments:
      - prod
      - prod-s2
      - prod-s3
      - prod-s4
      - prod-s5
      - prod-s6
      - prod-s7
      - prod-s8
      - prod-s9
      - prod-s101
      - prod-s201
  prod:
    description: All US production environments
    environments:
      - prod
      - prod-s2
      - prod-s3
      - prod-s4
      - prod-s5
      - prod-s6
      - prod-s7
      - prod-s8
      - prod-s9
  eu-prod:
    description: All EU production environments
    environments:
      - prod-s101
  apse-prod:
    description: All AP Southeast production environments
    environments:
      - prod-s201
  us-staging:
    description: All US staging environments
    environments:
      - staging
      - staging-s2
      - staging-s3
  eu-staging:
    description: All EU staging environments
    environments:
      - staging-s101
  apse-staging:
    description: All AP Southeast staging environments
    environments:
      - staging-s201
```

## Usage

### List Available Groups

```bash
lsql -g list
```

This will display all available groups, their descriptions, and the environments in each group.

### Execute Command Against a Group

```bash
# Run a SQL query against all environments in the 'dev' group
lsql "SELECT count(*) FROM users" -g dev

# Run a SQL file against all environments in the 'staging' group
lsql query.sql -g staging

# Run a query against a group and save output files
lsql "SELECT * FROM users LIMIT 10" -g dev -o user_sample
```

### Output Files with Groups

When using the `-o` option with groups:

**With Aggregation (default):**
- Creates a single output file with aggregated results
- Environment names are prefixed to each data row
- Headers appear only once

**Without Aggregation (`-n` flag):**
- Creates separate output files for each environment
- Environment name is appended to the filename
- Each file contains complete result set for that environment

Examples:
- `-o results` with aggregation → single `results` file with prefixed data
- `-o results -n` with group containing `staging`, `staging-s2` → creates `results_staging` and `results_staging-s2`

## Limitations

1. **Interactive Sessions**: Interactive sessions (`psql` console) are not supported with group operations. You must provide an SQL command or file.

2. **Mutual Exclusivity**: You cannot specify both `-e` (environment) and `-g` (group) options at the same time.

3. **Output Aggregation**: By default, group operations aggregate output. Use `-n` to disable aggregation and get separate outputs per environment.

4. **Error Handling**: If any environment in the group fails, the operation will continue with the remaining environments. A summary will be displayed at the end showing which environments succeeded and which failed.

## Error Handling

The tool provides comprehensive error handling:

- **Invalid Groups**: If a group doesn't exist, it will show available groups
- **Empty Groups**: If a group has no environments, it will show an error
- **Configuration Errors**: If the YAML file is malformed, it will show a parsing error
- **Environment Failures**: Individual environment failures are captured and reported in the summary

## Examples

```bash
# List all available groups
lsql -g list

# Execute a query on all staging environments (aggregated output, simple progress)
lsql "SELECT version()" -g staging

# Execute a query on all staging environments (aggregated output, verbose progress)  
lsql "SELECT version()" -g staging -v

# Execute a query on all staging environments (separate outputs, simple)
lsql "SELECT version()" -g staging -n

# Execute a query on all staging environments (separate outputs, verbose)
lsql "SELECT version()" -g staging -n -v

# Run a migration script on all US production environments
lsql migrate.sql -g us-prod

# Check database sizes across all production environments (aggregated)
lsql "SELECT pg_size_pretty(pg_database_size(current_database()))" -g all-prod -o db_sizes

# Run a complex query on EU environments with separate output files
lsql complex_query.sql -g eu-prod -o eu_analysis_results -n

# Check staging environments in AP Southeast (aggregated to stdout)
lsql "SELECT current_timestamp, current_database()" -g apse-staging
```
