# frozen_string_literal: true

require 'optparse'
require 'ostruct'
require_relative 'output_file_manager'

module Lsql
  # Handles command-line option parsing
  class CommandLineParser
    def initialize
      @options = OpenStruct.new(
        env: nil,
        region: nil,
        application: 'greenhouse',
        space: nil,
        output_file: nil,
        sql_command: nil,
        mode: 'rw',
        group: nil,
        no_agg: false,
        no_color: false,
        verbose: false,
        quiet: false,
        clear_cache: false,
        cache_prefix: nil,
        cache_stats: false,
        cache_ttl: nil,
        show_config: false,
        init_config: false,
        parallel: nil
      )
    end

    def parse(args)
      # First check if the first argument is an SQL command
      @options.sql_command = args.shift if args.first && !args.first.start_with?('-')

      # Parse options
      option_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [<SQL_COMMAND>] [options]"

        opts.separator ''
        opts.separator 'SQL_COMMAND can be:'
        opts.separator '  - SQL statement to execute directly'
        opts.separator '  - Path to a file containing SQL statements'
        opts.separator '  - If omitted, an interactive psql session will be started'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-e ENV', 'Environment (required unless using -g)') do |env|
          @options.env = env
        end

        opts.on('-g GROUP', '--group GROUP', 'Group name to execute against all environments in the group',
                '  Use "list" to see available groups') do |group|
          @options.group = group
        end

        opts.on('-A', '--no-agg', 'Disable output aggregation for group operations',
                '  By default, group output is aggregated with environment prefixes') do
          @options.no_agg = true
        end

        opts.on('-C', '--no-color', 'Disable color codes for interactive psql sessions',
                '  Only affects interactive sessions, not query result output') do
          @options.no_color = true
        end

        opts.on('-p', '--parallel [THREADS]', Integer, 'Enable parallel execution for group operations',
                '  Specify number of concurrent threads (default: number of CPU cores)',
                '  Use with caution - high concurrency may impact database performance') do |threads|
          @options.parallel = threads || 0 # 0 means auto-detect CPU cores
        end

        opts.on('-v', '--verbose', 'Enable verbose output for group operations',
                '  Shows detailed progress per environment (default: simple progress dots)') do
          @options.verbose = true
        end

        opts.on('-q', '--quiet', 'Suppress execution summary and output headers',
                '  Reduces output to just the query results') do
          @options.quiet = true
        end

        opts.on('-o [OUTPUT_FILE]', 'Output file (optional)',
                '  If specified without value, generates automatic filename',
                "  Default output directory: #{OutputFileManager::DEFAULT_OUTPUT_DIR}") do |output_file|
          @options.output_file = output_file || 'PLACEHOLDER'
        end

        opts.on('-r REGION', 'Region (optional)',
                '  Default is determined from ENV:',
                '    - Environments ending with 2XX -> apse2',
                '    - Environments ending with 1XX -> euc1',
                '    - Other environments -> use1') do |region|
          @options.region = region
        end

        opts.on('-a APPLICATION', "Application (optional, default: \"#{@options.application}\")") do |application|
          @options.application = application
        end

        opts.on('-s SPACE', 'Space (optional)',
                '  Default is determined from ENV:',
                '    - prod/staging environments -> prod',
                '    - other environments -> dev') do |space|
          @options.space = space
        end

        opts.on('-m MODE', '--mode MODE',
                'Database connection mode (optional, default: "rw")',
                '  rw             - Read-write access (uses primary database)',
                '  ro/r1/primary  - Read-only access using primary replica',
                '  r2/secondary   - Read-only access using secondary replica',
                '  r3/tertiary    - Read-only access using tertiary replica',
                '  <custom>       - Uses custom replica name') do |mode|
          @options.mode = mode
        end

        opts.on('--clear-cache', 'Clear the persistent database URL cache',
                '  Cache backend: Redis (if REDIS_URL set) or local files (~/.lsql/cache)') do
          @options.clear_cache = true
        end

        opts.on('--cache-prefix PREFIX', 'Custom cache key prefix (default: db_url)',
                '  Cache keys use format: lsql:{prefix}:{space}_{env}_{region}_{app}',
                '  Can also be set via LSQL_CACHE_PREFIX environment variable or config file') do |prefix|
          @options.cache_prefix = prefix
        end

        opts.on('--cache-ttl MINUTES', Integer, 'Cache TTL in minutes (default: 10)',
                '  How long database URLs are cached before requiring fresh lookup',
                '  Can also be set via LSQL_CACHE_TTL environment variable or config file') do |ttl|
          @options.cache_ttl = ttl
        end

        opts.on('--cache-stats', 'Show cache statistics and TTL information') do
          @options.cache_stats = true
        end

        opts.on('--show-config', 'Show current configuration settings') do
          @options.show_config = true
        end

        opts.on('--init-config', 'Create default configuration file') do
          @options.init_config = true
        end

        opts.on('-h', '--help', 'Display this help message') do
          puts opts
          exit
        end

        opts.separator ''
        opts.separator 'Examples:'
        opts.separator "  #{File.basename($PROGRAM_NAME)} -e dev01                          # Start interactive session for dev01"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -e prod01   # Run query on prod01"
        opts.separator "  #{File.basename($PROGRAM_NAME)} query.sql -e staging -o results   # Run query file on staging and save results"
        opts.separator "  #{File.basename($PROGRAM_NAME)} -e dev01 -r use1 -a customapp     # Connect to customapp in use1 region"
        opts.separator "  #{File.basename($PROGRAM_NAME)} -e prod01 -m ro                   # Connect using primary replica"
        opts.separator "  #{File.basename($PROGRAM_NAME)} -e prod01 -m secondary            # Connect using secondary replica"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT count(*) FROM users\" -g staging # Run query on all staging environments"
        opts.separator "  #{File.basename($PROGRAM_NAME)} query.sql -g us-prod -o results    # Run query file on all US production environments"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -A # Run query with separate output per environment"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -v # Run query with verbose progress output"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -p # Run query with parallel execution (auto CPU cores)"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -p 4 # Run query with 4 parallel threads"
        opts.separator "  #{File.basename($PROGRAM_NAME)} -g list                        # List all available groups"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --clear-cache                 # Clear persistent cached database URLs"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --cache-prefix myapp --clear-cache # Clear cache with custom prefix"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --cache-stats                 # Show cache statistics and TTL info"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --show-config                 # Show current configuration settings"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --init-config                 # Create default configuration file"
        opts.separator ''
        opts.separator 'Configuration:'
        opts.separator '  Settings priority: CLI arguments > ~/.lsql/config.yml > environment variables > defaults'
        opts.separator '  Configuration file example (~/.lsql/config.yml):'
        opts.separator '    cache:'
        opts.separator '      prefix: "myteam"'
        opts.separator '      ttl_minutes: 15'
        opts.separator '    groups:'
        opts.separator '      my-envs:'
        opts.separator '        description: "My custom environments"'
        opts.separator '        environments: ["env1", "env2"]'
        opts.separator '  Environment variables: LSQL_CACHE_PREFIX, LSQL_CACHE_TTL, LSQL_CACHE_DIR, LSQL_CACHE_KEY'
      end

      begin
        option_parser.parse!(args)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
        puts "Error: #{e.message}"
        puts option_parser
        exit 1
      end

      # Check required parameters (skip when clearing cache, showing stats, config operations)
      unless @options.clear_cache || @options.cache_stats || @options.show_config || @options.init_config
        if @options.env.nil? && @options.group.nil?
          puts 'Error: Either Environment (-e) or Group (-g) is required.'
          puts option_parser
          exit 1
        end

        if @options.env && @options.group
          puts 'Error: Cannot specify both Environment (-e) and Group (-g) options.'
          puts option_parser
          exit 1
        end
      end

      @options
    end
  end
end
