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

      # Setup environment
      EnvironmentManager.new(options)

      # Setup output file if needed
      output_manager = OutputFileManager.new(options)

      # Setup database connection
      db_connector = DatabaseConnector.new(options)
      database_url = db_connector.get_database_url

      # Execute SQL
      executor = SqlExecutor.new(options, output_manager, db_connector)
      executor.execute(database_url)
    end
  end
end
