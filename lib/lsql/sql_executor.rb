# frozen_string_literal: true

require 'fileutils'
require 'open3'
require_relative 'config_manager'

module Lsql
  # Handles SQL execution (interactive, file, command)
  class SqlExecutor
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

      # Construct the prompt using configuration
      psql_prompt = build_prompt

      # Pass the custom prompt directly to psql
      system("psql \"#{database_url}\" --set=PROMPT1=\"#{psql_prompt}\" --set=PROMPT2=\"#{psql_prompt}\"")
    end

    def build_prompt
      if @options.no_color
        build_plain_prompt
      else
        build_colored_prompt
      end
    end

    def build_plain_prompt
      templates = ConfigManager.get_prompt_templates
      template = templates['plain'] || '{space}:{mode_short} > {env}{mode}:%/%R%# '

      # Create variables for substitution
      space_display = (@options.space || 'UNKNOWN').upcase
      mode_short = get_mode_short_display

      # Substitute variables in template
      template.gsub('{space}', space_display)
              .gsub('{mode_short}', mode_short)
              .gsub('{env}', @options.env.to_s)
              .gsub('{mode}', @database_connector.mode_display.to_s)
    end

    def build_colored_prompt
      templates = ConfigManager.get_prompt_templates
      colors = ConfigManager.get_prompt_colors
      template = templates['colored'] || "{color}{env}{mode}:%/%R%#{reset} "

      # Determine color based on environment
      color = if ConfigManager.is_production_environment?(@options.env)
                colors['production'] || "\033[0;31m"
              else
                colors['development'] || "\033[0;32m"
              end
      reset = colors['reset'] || "\033[0m"

      # Substitute variables in template
      template.gsub('{color}', color)
              .gsub('{reset}', reset)
              .gsub('{env}', @options.env.to_s)
              .gsub('{mode}', @database_connector.mode_display.to_s)
    end

    def get_mode_short_display
      if @database_connector.mode_display.empty?
        'RW'
      else
        # Extract mode from [RO-PRIMARY] -> R1, [RO-SECONDARY] -> R2, etc.
        case @database_connector.mode_display
        when '[RO-PRIMARY]'
          'R1'
        when '[RO-SECONDARY]'
          'R2'
        when '[RO-TERTIARY]'
          'R3'
        else
          @database_connector.mode_display.gsub(/[\[\]]/, '').upcase
        end
      end
    end

    def run_sql_file(database_url, options)
      # Extract and print the hostname from the database URL (only in verbose mode)
      if @options.respond_to?(:verbose) && @options.verbose
        hostname = @database_connector.extract_hostname(database_url)
        puts "Connecting to: #{hostname}"
      end

      # Validate the file contains SQL commands
      File.open(@options.sql_command, 'r') do |file|
        sql_content = file.read
        unless sql_content =~ /^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|WITH|BEGIN|COMMIT|ROLLBACK)/i
          puts "The file '#{@options.sql_command}' does not contain valid SQL commands."
          exit 1
        end
      end

      if @options.output_file
        run_formatted_sql_file(database_url, options)
      else
        run_formatted_sql_to_stdout(database_url, options, @options.sql_command, file: true)
      end
    end

    def run_sql_command(database_url, options)
      # Extract and print the hostname from the database URL (only in verbose mode)
      if @options.respond_to?(:verbose) && @options.verbose
        hostname = @database_connector.extract_hostname(database_url)
        puts "Connecting to: #{hostname}"
      end

      if @options.output_file
        run_formatted_sql_command(database_url, options)
      else
        run_formatted_sql_to_stdout(database_url, options, @options.sql_command, file: false)
      end
    end

    def run_formatted_sql_file(database_url, options)
      if needs_format_conversion?
        # Use temporary file for format conversion
        # For JSON/YAML conversion, we need tab-separated output
        temp_file = "/tmp/lsql_temp_#{Process.pid}.txt"
        conversion_options = '-t -A'
        command = "psql -d \"#{database_url}\" #{conversion_options} -f \"#{@options.sql_command}\" > \"#{temp_file}\""
        execute_psql_command(command)

        convert_and_write_format(temp_file, @options.output_file)
        FileUtils.rm_f(temp_file)
      else
        # Direct output for CSV and TXT formats
        command = "psql -d \"#{database_url}\" #{options} -f \"#{@options.sql_command}\" > \"#{@options.output_file}\""
        execute_psql_command(command)
      end

      # Append the SQL file content to the output file
      @output_manager.append_sql_file_to_output_file(@options.sql_command)
    end

    def run_formatted_sql_command(database_url, options)
      if needs_format_conversion?
        # Use temporary file for format conversion
        # For JSON/YAML conversion, we need tab-separated output
        temp_file = "/tmp/lsql_temp_#{Process.pid}.txt"
        conversion_options = '-t -A'
        command = "psql -d \"#{database_url}\" #{conversion_options} -c \"#{@options.sql_command}\" > \"#{temp_file}\""
        execute_psql_command(command)

        convert_and_write_format(temp_file, @options.output_file)
        FileUtils.rm_f(temp_file)
      else
        # Direct output for CSV and TXT formats
        command = "psql -d \"#{database_url}\" #{options} -c \"#{@options.sql_command}\" > \"#{@options.output_file}\""
        execute_psql_command(command)
      end

      # Append the SQL command to the output file
      @output_manager.append_sql_command_to_output_file(@options.sql_command)
    end

    def run_formatted_sql_to_stdout(database_url, options, sql_command, file:)
      if needs_format_conversion?
        # Use temporary file for format conversion, then output to stdout
        # For JSON/YAML conversion, we need tab-separated output
        temp_file = "/tmp/lsql_temp_#{Process.pid}.txt"
        conversion_options = '-t -A'
        command = if file
                    "psql -d \"#{database_url}\" #{conversion_options} -f \"#{sql_command}\" > \"#{temp_file}\""
                  else
                    "psql -d \"#{database_url}\" #{conversion_options} -c \"#{sql_command}\" > \"#{temp_file}\""
                  end
        execute_psql_command(command)

        convert_and_output_format(temp_file)
        FileUtils.rm_f(temp_file)
      elsif file
        # Direct output for CSV and TXT formats
        execute_psql_command("psql -d \"#{database_url}\" -f \"#{sql_command}\" #{options}")
      else
        execute_psql_command("psql -d \"#{database_url}\" -c \"#{sql_command}\" #{options}")
      end
    end

    def needs_format_conversion?
      return false if using_aggregator_temp_file?

      @options.format && %w[json yaml].include?(@options.format)
    end

    def using_aggregator_temp_file?
      # Check if we're using a temporary file created by the output aggregator
      # These files are used for group operations and should not be format-converted
      return false unless @options.output_file

      @options.output_file.include?('lsql_temp') ||
        (@options.respond_to?(:group) && @options.group && !@options.no_agg)
    end

    def convert_and_write_format(input_file, output_file)
      case @options.format
      when 'json'
        convert_to_json(input_file, output_file)
      when 'yaml'
        convert_to_yaml(input_file, output_file)
      end
    end

    def convert_and_output_format(input_file)
      case @options.format
      when 'json'
        puts convert_to_json_string(input_file)
      when 'yaml'
        puts convert_to_yaml_string(input_file)
      end
    end

    def convert_to_json(input_file, output_file)
      File.write(output_file, convert_to_json_string(input_file))
    end

    def convert_to_yaml(input_file, output_file)
      File.write(output_file, convert_to_yaml_string(input_file))
    end

    def convert_to_json_string(input_file)
      require 'json'

      lines = File.readlines(input_file).map(&:chomp)
      return '[]' if lines.empty?

      # Parse tab-separated values from psql -t -A output
      headers = lines[0].split("\t")
      data = lines[1..].map { |line| line.split("\t") }

      # Convert to array of hashes
      result = data.map do |row|
        headers.zip(row).to_h
      end

      JSON.pretty_generate(result)
    end

    def convert_to_yaml_string(input_file)
      require 'yaml'

      lines = File.readlines(input_file).map(&:chomp)
      return '[]' if lines.empty?

      # Parse tab-separated values from psql -t -A output
      headers = lines[0].split("\t")
      data = lines[1..].map { |line| line.split("\t") }

      # Convert to array of hashes
      result = data.map do |row|
        headers.zip(row).to_h
      end

      result.to_yaml
    end

    def execute_psql_command(command)
      # For commands with output redirection, we need to handle them differently
      # to preserve the file output while still catching DNS errors
      if command.include?(' > ')
        # Split the command to separate psql from redirection
        parts = command.split(' > ', 2)
        psql_command = parts[0]
        output_file = parts[1].strip.gsub(/^"|"$/, '') # Remove quotes if present

        # Execute psql command and capture output
        stdout, stderr, status = Open3.capture3(psql_command)

        # Check for DNS resolution errors that indicate VPN issues
        if !status.success? && stderr.include?('could not translate host name')
          hostname = extract_hostname_from_error(stderr)
          if hostname&.match?(/\.rds\.amazonaws\.com/)
            puts "\n❌ Connection failed: Cannot resolve hostname '#{hostname}'"
            puts '💡 This usually indicates that your VPN connection is not active.'
            puts '   Please connect to your VPN and try again.'
            exit 1
          end
        end

        # If successful, write output to the specified file
        if status.success?
          File.write(output_file, stdout)
        else
          # For other errors, write error output and exit
          warn stdout unless stdout.empty?
          warn stderr unless stderr.empty?
          exit status.exitstatus
        end
      else
        # For commands without redirection, execute normally and capture all output
        stdout, stderr, status = Open3.capture3(command)

        # Check for DNS resolution errors that indicate VPN issues
        if !status.success? && stderr.include?('could not translate host name')
          hostname = extract_hostname_from_error(stderr)
          if hostname&.match?(/\.rds\.amazonaws\.com/)
            puts "\n❌ Connection failed: Cannot resolve hostname '#{hostname}'"
            puts '💡 This usually indicates that your VPN connection is not active.'
            puts '   Please connect to your VPN and try again.'
            exit 1
          end
        end

        # For other errors, just let the command fail normally
        unless status.success?
          warn stderr unless stderr.empty?
          exit status.exitstatus
        end

        # Print stdout if there's any (for non-redirected commands)
        print stdout unless stdout.empty?
      end
    end

    def extract_hostname_from_error(error_message)
      # Extract hostname from error like: could not translate host name "hostname" to address
      match = error_message.match(/could not translate host name "([^"]+)"/)
      match ? match[1] : nil
    end
  end
end
