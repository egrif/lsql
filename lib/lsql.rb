# frozen_string_literal: true

require_relative 'lsql/version'
require_relative 'lsql/command_line_parser'
require_relative 'lsql/output_file_manager'
require_relative 'lsql/environment_manager'
require_relative 'lsql/database_connector'
require_relative 'lsql/sql_executor'
require_relative 'lsql/group_handler'
require_relative 'lsql/output_aggregator'

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
