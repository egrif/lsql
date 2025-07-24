# frozen_string_literal: true

require 'tempfile'
require 'open3'

module Lsql
  # Handles aggregated output for group operations
  class OutputAggregator
    def initialize(options)
      @options = options
      @temp_files = []
      @header_written = false
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

      output_stream = output_file ? File.open(output_file, 'w') : $stdout

      # Calculate the maximum environment name length for alignment
      max_env_length = @temp_files.map { |temp_info| temp_info[:env].length }.max

      begin
        @temp_files.each_with_index do |temp_info, index|
          env = temp_info[:env]
          temp_file = temp_info[:file]

          # Ensure the temp file is closed and data is written
          temp_file.close unless temp_file.closed?

          next unless File.exist?(temp_file.path) && File.size(temp_file.path).positive?

          lines = File.readlines(temp_file.path)
          next if lines.empty?

          if index.zero? || !@header_written
            # For the first environment, write the header with environment column
            header_lines = extract_header_lines(lines)
            if header_lines.any?
              # Add environment column to the header
              env_header = 'environment'.ljust(max_env_length)
              header_lines.each_with_index do |line, line_index|
                if line.match?(/^\s*-+(\+.*)?-*\s*$/)
                  # Separator line - add dashes for environment column
                  env_separator = '-' * max_env_length
                  output_stream.puts "#{env_separator}-+-#{line.chomp}"
                elsif line_index.zero? && !line.strip.empty?
                  # First header line - add environment column
                  output_stream.puts "#{env_header} | #{line.chomp}"
                else
                  # Other header lines (empty lines, etc.)
                  padding = ' ' * max_env_length
                  output_stream.puts "#{padding} | #{line.chomp}"
                end
              end
            end
            @header_written = true
          end

          # Write data lines with environment prefix
          data_lines = extract_data_lines(lines)
          data_lines.each do |line|
            prefixed_line = prefix_line_with_env(line, env, max_env_length)
            output_stream.puts prefixed_line
          end
        end
      ensure
        output_stream.close if output_file && output_stream != $stdout
        cleanup_temp_files
      end
    end

    def cleanup_temp_files
      @temp_files.each do |temp_info|
        temp_file = temp_info[:file]
        temp_file.unlink if temp_file && !temp_file.closed?
      end
      @temp_files.clear
    end

    private

    def extract_header_lines(lines)
      header_lines = []

      lines.each_with_index do |line, index|
        # Include header lines and the separator line
        if line.match?(/^\s*-+(\+.*)?-*\s*$/) || line.match?(/^\s*=+\s*$/)
          # This is a separator line - include it and stop
          header_lines << line
          break
        elsif index.zero? || line.strip.empty? || is_likely_header(line, index)
          header_lines << line
        else
          # If we hit a non-header line before finding a separator,
          # assume no proper table format
          break
        end
      end

      header_lines
    end

    def extract_data_lines(lines)
      data_lines = []
      found_separator = false

      lines.each do |line|
        if line.match?(/^\s*-+(\+.*)?-*\s*$/) || line.match?(/^\s*=+\s*$/)
          found_separator = true
          next
        end

        # Skip metadata lines like "(X rows)" or timing information
        next if line.match?(/^\s*\(\d+\s+rows?\)\s*$/)
        next if line.match?(/Time:/)

        if found_separator && !line.strip.empty?
          data_lines << line
        elsif !found_separator && !is_likely_header(line, 0) && !line.strip.empty?
          # If no separator found, assume everything after potential headers is data
          data_lines << line
        end
      end

      data_lines
    end

    def is_likely_header(line, index)
      # Column headers are typically in the first few lines and contain letters
      return false if index > 3

      # Check if line looks like column headers (contains letters, spaces, pipes)
      line.match?(/^[a-zA-Z\s|_-]+$/) && line.include?(' ')
    end

    def prefix_line_with_env(line, env, max_env_length)
      # Remove trailing newline, add environment prefix with proper alignment, restore newline
      clean_line = line.chomp
      return clean_line if clean_line.strip.empty?

      padded_env = env.ljust(max_env_length)
      "#{padded_env} | #{clean_line}"
    end
  end
end
