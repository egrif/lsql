# frozen_string_literal: true

require_relative 'lsql/version'
require_relative 'lsql/command_line_parser'
require_relative 'lsql/output_file_manager'
require_relative 'lsql/environment_manager'
require_relative 'lsql/database_connector'
require_relative 'lsql/sql_executor'
require_relative 'lsql/group_handler'
require_relative 'lsql/output_aggregator'
require_relative 'lsql/cache_manager'
require_relative 'lsql/config_manager'

module Lsql
  class Error < StandardError; end

  # Main application class that coordinates the other components
  class Application
    def initialize
      @parser = CommandLineParser.new
    end

    def run(args = ARGV)
      # Parse command-line options
      options = @parser.parse(args)

      # Handle configuration operations
      if options.show_config
        cli_ttl = options.cache_ttl && (options.cache_ttl * 60) # Convert to seconds for consistency
        puts LSQL::ConfigManager.show_config(options.cache_prefix, cli_ttl)
        return
      end

      if options.init_config
        LSQL::ConfigManager.create_default_config
        puts "Configuration file created at #{LSQL::ConfigManager.config_file_path}"
        puts 'Edit this file to customize your cache settings.'
        return
      end

      # Handle cache clearing if requested
      if options.clear_cache
        # Use proper configuration resolution for cache parameters
        cache_ttl = if options.cache_ttl
                      options.cache_ttl * 60 # Convert minutes to seconds
                    elsif ENV['LSQL_CACHE_TTL']
                      ENV['LSQL_CACHE_TTL'].to_i * 60
                    else
                      LSQL::ConfigManager.get_cache_ttl
                    end

        cache = LSQL::CacheManager.instance(options.cache_prefix, cache_ttl)
        cache.clear_cache
        puts 'Database URL cache cleared successfully'
        return
      end

      # Handle cache stats if requested
      if options.cache_stats
        # Use proper configuration resolution for cache parameters
        cache_ttl = if options.cache_ttl
                      options.cache_ttl * 60 # Convert minutes to seconds
                    elsif ENV['LSQL_CACHE_TTL']
                      ENV['LSQL_CACHE_TTL'].to_i * 60
                    else
                      LSQL::ConfigManager.get_cache_ttl
                    end

        cache = LSQL::CacheManager.instance(options.cache_prefix, cache_ttl)
        stats = cache.cache_stats
        puts 'Cache Statistics:'
        puts "  Backend: #{stats[:backend]}"
        puts "  Prefix: #{stats[:prefix]}"
        puts "  Total entries: #{stats[:total_entries]}"
        puts "  TTL: #{stats[:ttl_seconds]} seconds (#{stats[:ttl_seconds] / 60} minutes)"
        puts "  Encryption: #{stats[:encryption]}"
        puts "  Location: #{stats[:location]}"
        return
      end

      # Check if we're running against a group
      if options.group
        group_handler = GroupHandler.new(options)
        group_handler.execute_for_group
        return
      end

      # Setup environment manager (handles both single and multiple environments)
      env_manager = EnvironmentManager.new(options)

      # Check if we have multiple environments (à la carte)
      if env_manager.multiple_environments?
        # Prevent interactive sessions with multiple environments
        if options.sql_command.nil?
          puts 'Error: Interactive sessions are not supported with multiple environments.'
          puts 'Please provide an SQL command or file to execute.'
          return
        end

        puts "Executing across #{env_manager.environments.length} environments..."

        # Use GroupHandler's execution logic for multiple environments
        group_handler = GroupHandler.new(options)

        # Create aggregator for output collection (unless disabled)
        aggregator = options.no_agg ? nil : OutputAggregator.new(options)
        original_output_file = options.output_file

        # Execute using GroupHandler's existing parallel/sequential logic
        if env_manager.environments.length == 1 || options.parallel == false
          group_handler.send(:execute_environments_sequential, env_manager.environments, aggregator)
        else
          group_handler.send(:execute_environments_parallel, env_manager.environments, aggregator)
        end

        # Display aggregated output (same logic as in GroupHandler)
        display_aggregated_output(aggregator, original_output_file, options) if aggregator
        return
      end

      # Use the primary (and only) environment options
      primary_options = env_manager.primary_environment

      # Setup output file if needed
      output_manager = OutputFileManager.new(primary_options)

      # Setup database connection
      db_connector = DatabaseConnector.new(primary_options)
      database_url = db_connector.get_database_url

      # Execute SQL
      executor = SqlExecutor.new(primary_options, output_manager, db_connector)
      executor.execute(database_url)
    end

    private

    def display_aggregated_output(aggregator, original_output_file, options)
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
        display_aggregated_header(options)
        aggregator.aggregate_output(original_output_file)
      end
    end

    def display_aggregated_header(options)
      return if options.quiet

      puts "\n#{'=' * 60}"
      puts 'AGGREGATED OUTPUT'
      puts '=' * 60
    end
  end
end
