# frozen_string_literal: true

require 'yaml'
require 'pathname'
require 'concurrent-ruby'
require 'open3'
require 'set'
require_relative 'config_manager'

module Lsql
  # Handles group-based operations across multiple environments
  # rubocop:disable Metrics/ClassLength
  class GroupHandler
    def initialize(options)
      @options = options
    end

    def execute_for_group
      return false unless @options.group

      # Special case: list groups
      if @options.group == 'list'
        list_groups
        return true
      end

      # Prevent interactive sessions with groups
      if @options.sql_command.nil?
        puts 'Error: Interactive sessions are not supported with group operations.'
        puts 'Please provide an SQL command or file to execute against the group.'
        exit 1
      end

      LSQL::ConfigManager.load_config
      environments = LSQL::ConfigManager.get_group_environments(@options.group)

      if environments.empty?
        puts "Error: Group '#{@options.group}' not found or has no environments."
        puts 'Available groups:'
        LSQL::ConfigManager.list_available_groups
        exit 1
      end

      puts "Executing command for group '#{@options.group}' with environments: #{environments.join(', ')}"
      if @options.parallel == false
        puts 'Using sequential execution (parallel disabled)'
      else
        thread_count = @options.parallel.zero? ? Concurrent.processor_count : @options.parallel
        puts "Using parallel execution with #{thread_count} threads"
      end
      puts '=' * 60

      # Initialize output aggregator if aggregation is enabled
      # Use aggregation unless --no-agg flag is specified
      aggregator = @options.no_agg ? nil : OutputAggregator.new(@options)
      original_output_file = @options.output_file

      # Pre-ping lotus for all unique space/region combinations before execution
      pre_ping_lotus_combinations(environments)

      # Execute environments (parallel by default, sequential if --no-parallel specified)
      results = if @options.parallel == false
                  execute_environments_sequential(environments, aggregator)
                else
                  # Pre-authenticate with Lotus SSO before parallel execution to avoid multiple SSO prompts
                  pre_authenticate_lotus_sso(environments.first) if environments.any?
                  execute_environments_parallel(environments, aggregator)
                end

      # If using aggregation, handle output appropriately
      if aggregator
        if original_output_file
          # When outputting to a file, don't display aggregated results to stdout
          # Just aggregate to the file and show the file path
          aggregator.aggregate_output(original_output_file)
          puts "\n#{'=' * 60}"
          puts 'OUTPUT WRITTEN TO FILE'
          puts '=' * 60
          puts "File: #{original_output_file}"
        else
          # When no output file specified, display aggregated results to stdout
          unless @options.quiet
            puts "\n#{'=' * 60}"
            puts 'AGGREGATED OUTPUT'
            puts '=' * 60
          end
          aggregator.aggregate_output(original_output_file)
        end
      end

      print_summary(results)
      true
    end

    def execute_environments_sequential(environments, aggregator)
      # Initialize progress tracking for non-verbose mode (only for aggregated output)
      spinner_chars = ['|', '/', '-', '\\']
      spinner_index = 0
      if !@options.verbose && !@options.no_agg
        print 'Progress: '
        $stdout.flush
      end

      results = []
      environments.each_with_index do |env_options, index|
        # env_options is already a full options object with environment-specific settings
        env_name = env_options.env

        if @options.verbose
          puts "
[#{index + 1}/#{environments.length}] Processing environment: #{env_name}"
          puts '-' * 40
        elsif !@options.no_agg
          # Show dot at the beginning of each query and start spinner
          print '.'
          $stdout.flush
        end

        # Start spinner for non-verbose aggregated mode
        spinner_thread = nil
        if !@options.verbose && !@options.no_agg
          spinner_thread = Thread.new do
            loop do
              print "\b#{spinner_chars[spinner_index % 4]}"
              $stdout.flush
              spinner_index += 1
              sleep(0.2)
            end
          rescue ThreadError
            # Thread was killed, exit cleanly
          end
        end

        begin
          result = execute_for_environment(env_options, aggregator)
          results << { env: env_name, success: result }

          # Stop spinner and show completion
          if !@options.verbose && !@options.no_agg && spinner_thread
            spinner_thread.kill
            spinner_thread.join(0.1)
            print "\b "
            $stdout.flush
          elsif @options.verbose
            puts "✓ Completed environment: #{env_name}"
          end
        rescue StandardError => e
          # Stop spinner on error
          if !@options.verbose && !@options.no_agg && spinner_thread
            spinner_thread.kill
            spinner_thread.join(0.1)
            print "\b✗"
            $stdout.flush
          elsif @options.verbose
            puts "✗ Failed environment: #{env_name} - #{e.message}"
          end
          results << { env: env_name, success: false, error: e.message }
        end
      end

      # Complete the progress line for non-verbose mode (only for aggregated output)
      puts ' done' if !@options.verbose && !@options.no_agg

      results
    end

    def execute_environments_parallel(environments, aggregator)
      thread_count = @options.parallel.zero? ? Concurrent.processor_count : @options.parallel

      # Use a thread pool for controlled concurrency
      pool = Concurrent::FixedThreadPool.new(thread_count)

      # Shared state for progress tracking
      completed = Concurrent::AtomicFixnum.new(0)
      total = environments.length

      # Progress tracking for parallel execution
      progress_thread = nil
      unless @options.verbose
        if @options.no_agg
          puts "Processing #{environments.length} environments in parallel..."
        else
          print 'Progress: '
          $stdout.flush
          progress_thread = Thread.new do
            spinner_chars = ['|', '/', '-', '\\']
            spinner_index = 0
            loop do
              current = completed.value
              print "\r#{' ' * 50}\rProgress: #{'.' * current}#{spinner_chars[spinner_index % 4]} (#{current}/#{total})"
              $stdout.flush
              spinner_index += 1
              sleep(0.2)
              break if current >= total
            end
          rescue ThreadError
            # Thread was killed, exit cleanly
          end
        end
      end

      # Submit all tasks to the thread pool
      futures = environments.map do |env_options|
        Concurrent::Future.execute(executor: pool) do
          # env_options is already a full options object with environment-specific settings
          env_name = env_options.env

          puts "[PARALLEL] Starting environment: #{env_name}" if @options.verbose

          begin
            result = execute_for_environment(env_options, aggregator)
            completed.increment

            puts "[PARALLEL] ✓ Completed environment: #{env_name}" if @options.verbose

            { env: env_name, success: result }
          rescue StandardError => e
            completed.increment

            puts "[PARALLEL] ✗ Failed environment: #{env_name} - #{e.message}" if @options.verbose

            { env: env_name, success: false, error: e.message }
          end
        end
      end

      # Wait for all tasks to complete
      results = futures.map(&:value!)

      # Clean up progress thread
      if progress_thread
        progress_thread.kill
        progress_thread.join(0.1)
        puts "\r#{' ' * 50}\rProgress: #{'.' * total} done (#{total}/#{total})"
      elsif !@options.verbose && @options.no_agg
        puts 'All environments completed.'
      end

      # Shutdown the thread pool
      pool.shutdown
      pool.wait_for_termination(30) # Wait up to 30 seconds for clean shutdown

      results
    end

    def list_groups
      groups = LSQL::ConfigManager.get_groups

      if groups.empty?
        puts "No groups found in configuration file: #{LSQL::ConfigManager.config_file_path}"
        puts "Run 'lsql --init-config' to create a default configuration with sample groups."
        return
      end

      puts "Available groups in #{LSQL::ConfigManager.config_file_path}:"
      puts '=' * 50
      groups.each do |name, group_config|
        description = group_config['description'] || 'No description'
        environments = group_config['environments'] || []
        puts "#{name}:"
        puts "  Description: #{description}"
        puts "  Environments (#{environments.length}): #{environments.join(', ')}"
        puts ''
      end
    end

    private

    def pre_authenticate_lotus_sso(first_env)
      # Make a simple lotus ping to establish SSO session before parallel execution
      # This prevents multiple SSO authentication prompts when running in parallel
      return unless first_env

      puts 'Establishing SSO session...' if @options.verbose

      # Use lotus ping command which doesn't require any arguments
      cmd = 'lotus ping'

      _, stderr, status = Open3.capture3(cmd)

      if status.success?
        puts 'SSO session established successfully.' if @options.verbose
      else
        puts "Warning: Failed to establish SSO session: #{stderr}" if @options.verbose
        puts 'Proceeding with parallel execution - you may see multiple SSO prompts.'
      end
    rescue StandardError => e
      puts "Warning: Error during SSO pre-authentication: #{e.message}" if @options.verbose
      puts 'Proceeding with parallel execution - you may see multiple SSO prompts.'
    end

    def execute_for_environment(env_options, aggregator = nil)
      # env_options already has environment-specific settings configured

      # Setup output file if needed (modify filename to include environment or use aggregator)
      if aggregator
        # For aggregation, use a temporary file
        temp_file = aggregator.get_temp_file_for_env(env_options.env)
        env_options.output_file = temp_file
      elsif env_options.output_file
        # Create environment-specific output file
        original_output = env_options.output_file
        if original_output == 'PLACEHOLDER'
          env_options.output_file = "#{env_options.env}_output"
        else
          # Insert environment name before file extension
          ext = File.extname(original_output)
          base = File.basename(original_output, ext)
          dir = File.dirname(original_output)
          env_options.output_file = File.join(dir, "#{base}_#{env_options.env}#{ext}")
        end
      else
      end
      output_manager = OutputFileManager.new(env_options)

      # Setup database connection
      db_connector = DatabaseConnector.new(env_options)
      database_url = db_connector.get_database_url

      # Execute SQL
      executor = SqlExecutor.new(env_options, output_manager, db_connector)
      executor.execute(database_url)

      true
    rescue StandardError => e
      puts "Error executing for environment #{env_options.env}: #{e.message}" if @options.verbose
      false
    end

    def print_summary(results)
      return if @options.quiet

      puts "\n#{'=' * 60}"
      puts 'EXECUTION SUMMARY'
      puts '=' * 60

      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

      puts "✓ Successful: #{successful.length}"
      puts "  #{successful.map { |r| r[:env] }.join(', ')}" if successful.any?

      if failed.any?
        puts "\n✗ Failed: #{failed.length}"
        failed.each { |r| puts "  - #{r[:env]}: #{r[:error] || 'Unknown error'}" }
      end

      puts "\nTotal environments processed: #{results.length}"
    end

    # Pre-ping lotus only for space/region combinations where we need to call lotus
    # (i.e., where database URLs are not cached)
    def pre_ping_lotus_combinations(environments)
      # Check each environment to see if it needs a lotus call
      combinations_needing_ping = Set.new

      environments.each do |env|
        # Create temporary options to determine space and region for each environment
        env_options = @options.dup
        env_options.env = env

        # Initialize environment manager to determine space and region
        EnvironmentManager.new(env_options)

        # Check if database URL is already cached for this environment
        temp_connector = DatabaseConnector.new(env_options)
        cache = temp_connector.instance_variable_get(:@cache)

        if cache.url_cached_for_params?(space: env_options.space, env: env_options.env,
                                        region: env_options.region, application: env_options.application,
                                        cluster: env_options.cluster)
          puts "Environment #{env} cached - no lotus ping needed for #{env_options.space}/#{env_options.region}" if @options.verbose
        else
          # URL not cached - we'll need to call lotus, so ping is required
          combinations_needing_ping.add([env_options.space, env_options.region])
          puts "Environment #{env} not cached - will need lotus ping for #{env_options.space}/#{env_options.region}" if @options.verbose
        end
      end

      # Pre-ping only the combinations that need lotus calls
      if combinations_needing_ping.any?
        puts "Pre-pinging lotus for #{combinations_needing_ping.size} space/region combination(s) that need fresh database URLs..." if @options.verbose || !@options.quiet
        DatabaseConnector.ping_space_region_combinations(combinations_needing_ping.to_a, verbose: @options.verbose)
        puts 'Lotus pre-ping completed.' if @options.verbose || !@options.quiet
      elsif @options.verbose || !@options.quiet
        puts 'All database URLs cached - no lotus pings needed!'
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
