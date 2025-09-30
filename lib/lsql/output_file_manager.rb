# frozen_string_literal: true

require 'fileutils'
require 'date'

module Lsql
  # Manages output file configuration and setup
  class OutputFileManager
    DEFAULT_OUTPUT_DIR = File.expand_path('~/tmp')

    def initialize(options)
      @options = options
      FileUtils.mkdir_p(DEFAULT_OUTPUT_DIR)
      setup_output_file if @options.output_file && !temp_file?
    end

    def temp_file?
      # Check if the output file is a temporary file (contains temp directory path and lsql_temp)
      @options.output_file&.include?('lsql_temp')
    end

    def setup_output_file
      if @options.output_file == 'PLACEHOLDER'
        # Generate default output file name
        iso_date = Date.today.strftime('%Y%m%d')
        serial_integer = 1

        serial_integer += 1 while File.exist?("#{DEFAULT_OUTPUT_DIR}/#{iso_date}_#{@options.env}_#{format('%04d', serial_integer)}")

        @options.output_file = "#{DEFAULT_OUTPUT_DIR}/#{iso_date}_#{@options.env}_#{format('%04d', serial_integer)}"
      else
        # Append ENV and SERIAL_INTEGER to the provided output file name
        serial_integer = 1
        base_output_file = File.basename(@options.output_file, '.*')
        extension = File.extname(@options.output_file).delete('.')
        extension = extension.empty? ? '' : ".#{extension}"

        serial_integer += 1 while File.exist?("#{base_output_file}_#{@options.env}_#{format('%04d', serial_integer)}#{extension}")

        @options.output_file = "#{base_output_file}_#{@options.env}_#{format('%04d', serial_integer)}#{extension}"
      end
    end

    def get_psql_options
      return '' unless @options.output_file || (@options.respond_to?(:format) && @options.format)

      # If format is explicitly specified, use format-specific options
      # BUT never apply format options to temp files used by aggregator
      if @options.respond_to?(:format) && @options.format && !temp_file?
        case @options.format
        when 'csv'
          '-t -A -F"," '
        when 'json', 'yaml', 'txt'
          '-t -A '
        else
          ''
        end
      else
        # For file extension-based detection, only apply to non-temp files
        # Temp files (used by aggregator) should use default psql formatting
        return '' if temp_file?

        format = determine_format_from_extension
        case format
        when 'csv'
          '-t -A -F"," '
        when 'json', 'yaml'
          '-t -A '
        else
          ''
        end
      end
    end

    def append_sql_command_to_output_file(sql_command)
      return unless @options.output_file

      # Only append SQL command comment in non-aggregated mode with real output files
      # Skip for temporary files used in aggregation
      return if temp_file?

      File.open(@options.output_file, 'a') do |file|
        file.puts '/* SQL command:'
        file.puts sql_command
        file.puts '*/'
      end
    end

    def append_sql_file_to_output_file(sql_file)
      return unless @options.output_file

      # Only append SQL file comment in non-aggregated mode with real output files
      # Skip for temporary files used in aggregation
      return if temp_file?

      File.open(@options.output_file, 'a') do |file|
        file.puts '/* SQL file content:'
        file.puts File.read(sql_file)
        file.puts '*/'
      end
    end

    private

    def determine_format_from_extension
      return nil unless @options.output_file

      case File.extname(@options.output_file).downcase
      when '.csv'
        'csv'
      when '.json'
        'json'
      when '.yaml', '.yml'
        'yaml'
      when '.txt'
        'txt'
      else
        nil
      end
    end
  end
end
