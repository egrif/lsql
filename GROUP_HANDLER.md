# Group Handler Documentation

The LSQL tool now supports executing commands against groups of environments using the `-g` (or `--group`) option.

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

When using the `-o` option with groups, the tool will create separate output files for each environment in the group. The environment name will be appended to the filename.

For example:
- `-o results` with group containing `dev01`, `dev02` will create `results_dev01` and `results_dev02`
- `-o data.csv` with group containing `staging01`, `staging02` will create `data_staging01.csv` and `data_staging02.csv`

## Limitations

1. **Interactive Sessions**: Interactive sessions (`psql` console) are not supported with group operations. You must provide an SQL command or file.

2. **Mutual Exclusivity**: You cannot specify both `-e` (environment) and `-g` (group) options at the same time.

3. **Error Handling**: If any environment in the group fails, the operation will continue with the remaining environments. A summary will be displayed at the end showing which environments succeeded and which failed.

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

# Execute a query on all staging environments
lsql "SELECT version()" -g staging

# Run a migration script on all US production environments
lsql migrate.sql -g us-prod

# Check database sizes across all production environments
lsql "SELECT pg_size_pretty(pg_database_size(current_database()))" -g all-prod -o db_sizes

# Run a complex query on EU environments only
lsql complex_query.sql -g eu-prod -o eu_analysis_results

# Check staging environments in AP Southeast
lsql "SELECT current_timestamp" -g apse-staging
```
