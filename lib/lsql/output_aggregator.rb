# frozen_string_literal: true

require 'tempfile'
require 'open3'
require 'json'
require 'set'
require_relative 'data_extractor'

module Lsql
  # Handles aggregated output for group operations
  class OutputAggregator
    def initialize(options)
      @options = options
      @temp_files = []
    end

    def create_temp_file(env)
      temp_file = Tempfile.new(['lsql_temp', '.txt'])
      @temp_files << { env: env, file: temp_file }
      temp_file.path
    end

    def get_temp_file_for_env(env)
      create_temp_file(env)
    end

    def aggregate_output(output_file = nil)
      return if @temp_files.empty?

      data_extractor = DataExtractor.new
      structured_data = data_extractor.extract_from_temp_files(@temp_files)

      # Apply format conversion if specified, otherwise use default tabular format
      output = if @options.respond_to?(:format) && @options.format
                 convert_to_format(structured_data)
               else
                 format_output(structured_data, data_extractor)
               end

      write_or_print_output(output, output_file)
      cleanup_temp_files
    end

    def convert_to_format(structured_data)
      # Convert structured data to the requested format
      case @options.format
      when 'json'
        convert_to_json(structured_data)
      when 'yaml'
        convert_to_yaml(structured_data)
      when 'csv'
        convert_to_csv(structured_data)
      when 'txt'
        convert_to_txt(structured_data)
      else
        # Fallback to default tabular format
        format_output(structured_data)
      end
    end

    def convert_to_json(structured_data)
      require 'json'

      # Structure data with environment names as root keys
      env_grouped_data = {}
      structured_data.each do |env, env_data|
        env_grouped_data[env] = env_data
      end

      JSON.pretty_generate(env_grouped_data)
    end

    def convert_to_yaml(structured_data)
      require 'yaml'

      # Structure data with environment names as root keys
      env_grouped_data = {}
      structured_data.each do |env, env_data|
        env_grouped_data[env] = env_data
      end

      env_grouped_data.to_yaml
    end

    def convert_to_csv(structured_data)
      return '' if structured_data.empty?

      # Get all unique columns
      all_columns = Set.new(['env'])
      structured_data.each_value do |env_data|
        env_data.each { |row| all_columns.merge(row.keys) }
      end
      columns = all_columns.to_a

      # Build CSV output
      output = "#{columns.join(',')}\n"
      structured_data.each do |env, env_data|
        env_data.each do |row|
          row_values = columns.map { |col| col == 'env' ? env : (row[col] || '') }
          output << "#{row_values.join(',')}\n"
        end
      end

      output
    end

    def convert_to_txt(structured_data)
      # For TXT format, use tab-separated values
      return '' if structured_data.empty?

      # Get all unique columns
      all_columns = Set.new(['env'])
      structured_data.each_value do |env_data|
        env_data.each { |row| all_columns.merge(row.keys) }
      end
      columns = all_columns.to_a

      # Build tab-separated output
      output = "#{columns.join("\t")}\n"
      structured_data.each do |env, env_data|
        env_data.each do |row|
          row_values = columns.map { |col| col == 'env' ? env : (row[col] || '') }
          output << "#{row_values.join("\t")}\n"
        end
      end

      output
    end

    def cleanup_temp_files
      @temp_files.each do |temp_info|
        temp_file = temp_info[:file]
        temp_file.unlink if temp_file && !temp_file.closed?
      end
      @temp_files.clear
    end

    private

    # Format structured data into readable text output
    def format_output(structured_data, data_extractor = nil)
      return '' if structured_data.empty?

      max_env_length = calculate_max_env_length(structured_data.keys)
      all_columns = extract_all_columns(structured_data)

      # Use PostgreSQL column widths if available, otherwise calculate from data
      column_widths = if data_extractor && !data_extractor.column_widths.empty?
                        data_extractor.column_widths
                      else
                        calculate_column_widths(structured_data, all_columns)
                      end

      output = build_header_with_columns(max_env_length, all_columns, column_widths)
      output << build_separator_line(max_env_length, all_columns, column_widths)
      output << build_data_rows_with_columns(structured_data, max_env_length, all_columns, column_widths)
      output
    end

    # Calculate maximum environment name length for alignment
    def calculate_max_env_length(env_names)
      env_names.map(&:length).max || 0
    end

    # Extract all unique column names from all environments
    def extract_all_columns(structured_data)
      columns = Set.new
      structured_data.each_value do |env_data|
        env_data.each do |row|
          columns.merge(row.keys)
        end
      end
      columns.to_a
    end

    # Calculate column widths for proper alignment
    def calculate_column_widths(structured_data, columns)
      widths = {}
      columns.each { |col| widths[col] = col.length }

      structured_data.each_value do |env_data|
        env_data.each do |row|
          columns.each do |col|
            value_length = (row[col] || '').to_s.length
            widths[col] = [widths[col], value_length].max
          end
        end
      end
      widths
    end

    # Build header row with environment and all columns
    def build_header_with_columns(max_env_length, columns, column_widths)
      env_header = 'env'.ljust([3, max_env_length].max)
      column_headers = columns.map { |col| col.ljust(column_widths[col]) }
      "#{env_header} | #{column_headers.join(' | ')}\n"
    end

    # Build separator line
    def build_separator_line(max_env_length, columns, column_widths)
      env_sep = '-' * [3, max_env_length].max
      col_seps = columns.map { |col| '-' * column_widths[col] }
      "#{env_sep}-+-#{col_seps.join('-+-')}\n"
    end

    # Build data rows with environment and column values
    def build_data_rows_with_columns(structured_data, max_env_length, columns, column_widths)
      output = String.new

      structured_data.each do |env, env_data|
        env_data.each do |row|
          env_col = env.ljust([3, max_env_length].max)
          values = columns.map { |col| (row[col] || '').ljust(column_widths[col]) }
          output << "#{env_col} | #{values.join(' | ')}\n"
        end
      end

      output
    end

    # Write output to file or print to stdout
    def write_or_print_output(output, output_file)
      if output_file
        File.write(output_file, output)
      else
        print output
      end
    end
  end
end
