# frozen_string_literal: true

require 'optparse'
require 'ostruct'

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
        verbose: false,
        clear_cache: false
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

        opts.on('-n', '--no-agg', 'Disable output aggregation for group operations',
                '  By default, group output is aggregated with environment prefixes') do
          @options.no_agg = true
        end

        opts.on('-v', '--verbose', 'Enable verbose output for group operations',
                '  Shows detailed progress per environment (default: simple progress dots)') do
          @options.verbose = true
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

        opts.on('--clear-cache', 'Clear the database URL cache') do
          @options.clear_cache = true
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
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -n # Run query with separate output per environment"
        opts.separator "  #{File.basename($PROGRAM_NAME)} \"SELECT * FROM users\" -g staging -v # Run query with verbose progress output"
        opts.separator "  #{File.basename($PROGRAM_NAME)} -g list                        # List all available groups"
        opts.separator "  #{File.basename($PROGRAM_NAME)} --clear-cache                 # Clear cached database URLs"
      end

      begin
        option_parser.parse!(args)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
        puts "Error: #{e.message}"
        puts option_parser
        exit 1
      end

      # Check required parameters (skip when clearing cache)
      unless @options.clear_cache
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
