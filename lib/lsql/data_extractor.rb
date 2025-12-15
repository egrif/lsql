# frozen_string_literal: true

require 'json'

module Lsql
  # Extracts and structures data from SQL command output files
  class DataExtractor
    def initialize
      @data = {}
      @column_widths = {}
      @columns_by_env = {} # Store columns for each environment even when no rows
      @status_messages = {} # Store status messages for non-tabular output
    end

    # Extract data from temp files and return structured JSON
    def extract_from_temp_files(temp_files)
      temp_files.each do |temp_info|
        env = temp_info[:env]
        temp_file = temp_info[:file]

        temp_file.close unless temp_file.closed?
        next unless File.exist?(temp_file.path) && File.size(temp_file.path).positive?

        lines = File.readlines(temp_file.path)
        next if lines.empty?

        env_data, columns = parse_postgresql_output(lines)

        if env_data.empty? && columns.empty?
          # Try to extract status message if no tabular data found
          status = extract_status_message(lines)
          @status_messages[env] = status if status
          # Ensure we have an entry in @data so the aggregator knows about this env
          @data[env] = []
        else
          @data[env] = env_data
          @columns_by_env[env] = columns if columns && !columns.empty?
        end
      end

      @data
    end

    # Get columns for an environment (even if no rows)
    def get_columns_for_env(env)
      @columns_by_env[env] || []
    end

    # Get extracted column width information
    attr_reader :column_widths, :status_messages

    # Get data as JSON string
    def to_json(*_args)
      JSON.pretty_generate(@data)
    end

    # Get raw data hash
    def to_hash
      @data
    end

    private

    def extract_status_message(lines)
      # Join lines and strip whitespace
      content = lines.map(&:strip).reject(&:empty?).join(' ')
      return nil if content.empty?

      # Common PostgreSQL status messages
      return content if content.match?(/^(UPDATE|INSERT|DELETE|CREATE|DROP|ALTER|SET|GRANT|REVOKE|COPY|BEGIN|COMMIT|ROLLBACK)/i)

      # Handle "No relations found." or similar
      return '(no data returned)' if content.include?('No relations found')

      # Fallback: return the content itself if it's short, otherwise generic message
      content.length < 50 ? content : '(no data returned)'
    end

    # Parse PostgreSQL table output format
    # Returns [data_rows, columns] so columns are preserved even when no rows
    def parse_postgresql_output(lines)
      return [[], []] if lines.empty?

      # Find header line (first non-empty line)
      header_line = lines.find { |line| !line.strip.empty? }
      return [[], []] unless header_line

      header_index = lines.index(header_line)

      # Extract column names from header
      columns = extract_columns_from_header(header_line)
      return [[], []] if columns.empty?

      # Find separator line (should be after header)
      separator_index = find_separator_line(lines, header_index)
      # If no separator line found, it's likely not a table output (e.g. status message)
      return [[], []] unless separator_index

      # Extract column widths from separator line
      extract_column_widths_from_separator(lines[separator_index], columns)

      # Extract data rows (after separator, before footer)
      data_rows = extract_data_rows(lines, separator_index, columns)
      [data_rows, columns]
    end

    # Extract column names from header line
    def extract_columns_from_header(header_line)
      # Split by | and clean up column names
      columns = header_line.split('|').map(&:strip)
      columns.reject(&:empty?)
    end

    # Find the separator line (dashes and +)
    def find_separator_line(lines, start_index)
      ((start_index + 1)...lines.length).each do |i|
        line = lines[i].strip
        return i if line.match?(/^-+(\+-+)*$/)
      end
      nil
    end

    # Extract column widths from PostgreSQL separator line like "---+------"
    def extract_column_widths_from_separator(separator_line, columns)
      # Split by + and get the length of each dash segment
      dash_segments = separator_line.strip.split('+')
      widths = dash_segments.map(&:length)

      # Map widths to column names
      columns.each_with_index do |col, idx|
        @column_widths[col] = widths[idx] if idx < widths.length
      end
    end

    # Extract data rows and convert to hash objects
    def extract_data_rows(lines, separator_index, columns)
      data_rows = []

      ((separator_index + 1)...lines.length).each do |i|
        line = lines[i].strip

        # Stop at footer lines like "(1 row)" or empty lines
        break if line.empty? || line.match?(/^\(\d+\s+rows?\)$/) || line.match?(/^Time:/)

        # Parse data row
        # Use -1 limit to include trailing empty strings (for NULL/empty columns)
        values = line.split('|', -1).map(&:strip)
        next if values.length != columns.length

        # Create hash object with column names as keys
        row_data = {}
        columns.each_with_index do |column, idx|
          row_data[column] = values[idx]
        end

        data_rows << row_data
      end

      data_rows
    end
  end
end
