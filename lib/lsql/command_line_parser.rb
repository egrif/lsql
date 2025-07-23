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
        mode: 'rw'
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

        opts.on('-e ENV', 'Environment (required)') do |env|
          @options.env = env
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
      end

      begin
        option_parser.parse!(args)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
        puts "Error: #{e.message}"
        puts option_parser
        exit 1
      end

      # Check required parameters
      if @options.env.nil?
        puts 'Error: Environment (-e) is required.'
        puts option_parser
        exit 1
      end

      @options
    end
  end
end
