# frozen_string_literal: true

module Lsql
  # Handles SQL execution (interactive, file, command)
  class SqlExecutor
    COLORS = {
      red: "\033[0;31m",
      green: "\033[0;32m",
      reset: "\033[0m"
    }

    def initialize(options, output_manager, database_connector)
      @options = options
      @output_manager = output_manager
      @database_connector = database_connector
    end

    def execute(database_url)
      # If no SQL_COMMAND is provided, open a psql console
      if @options.sql_command.nil?
        run_interactive_session(database_url)
        return
      end

      # Determine psql options
      options = @output_manager.get_psql_options

      # Check if the SQL_COMMAND is a file
      if File.file?(@options.sql_command)
        run_sql_file(database_url, options)
      else
        run_sql_command(database_url, options)
      end
    end

    private

    def run_interactive_session(database_url)
      # Extract and print the hostname from the database URL
      hostname = @database_connector.extract_hostname(database_url)
      puts "Connecting to: #{hostname}"

      # Determine the prompt color based on the environment
      prompt_color = @options.env =~ /^prod/i ? COLORS[:red] : COLORS[:green]
      reset_color = COLORS[:reset]
      # Use the mode_display set during URL transformation
      psql_prompt = "#{prompt_color}#{@options.env}#{@database_connector.mode_display}:%/%R%##{reset_color} "

      # Pass the custom prompt directly to psql
      system("psql \"#{database_url}\" --set=PROMPT1=\"#{psql_prompt}\" --set=PROMPT2=\"#{psql_prompt}\"")
    end

    def run_sql_file(database_url, options)
      # Extract and print the hostname from the database URL
      hostname = @database_connector.extract_hostname(database_url)
      puts "Connecting to: #{hostname}"

      # Validate the file contains SQL commands
      File.open(@options.sql_command, 'r') do |file|
        sql_content = file.read
        unless sql_content =~ /^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|WITH|BEGIN|COMMIT|ROLLBACK)/i
          puts "The file '#{@options.sql_command}' does not contain valid SQL commands."
          exit 1
        end
      end

      if @options.output_file
        command = "psql -d \"#{database_url}\" #{options} -f \"#{@options.sql_command}\" > \"#{@options.output_file}\""
        system(command)

        # Append the SQL command to the output file
        @output_manager.append_sql_file_to_output_file(@options.sql_command)
      else
        system("psql -d \"#{database_url}\" -f \"#{@options.sql_command}\" #{options}")
      end
    end

    def run_sql_command(database_url, options)
      # Extract and print the hostname from the database URL
      hostname = @database_connector.extract_hostname(database_url)
      puts "Connecting to: #{hostname}"

      if @options.output_file
        command = "psql -d \"#{database_url}\" #{options} -c \"#{@options.sql_command}\" > \"#{@options.output_file}\""
        system(command)

        # Append the SQL command to the output file
        @output_manager.append_sql_command_to_output_file(@options.sql_command)
      else
        system("psql -d \"#{database_url}\" -c \"#{@options.sql_command}\" #{options}")
      end
    end
  end
end
