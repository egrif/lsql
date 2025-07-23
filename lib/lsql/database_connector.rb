# frozen_string_literal: true

require 'open3'

module Lsql
  # Handles database URL retrieval and transformation
  class DatabaseConnector
    attr_reader :mode_display

    def initialize(options)
      @options = options
      @mode_display = ''
    end

    def get_database_url
      # Always get the main database URL - never use any other secret name
      cmd = "lotus secret get DATABASE_MAIN_URL -s \"#{@options.space}\" -e \"#{@options.env}\" -r \"#{@options.region}\" -a \"#{@options.application}\""
      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        database_url = stdout.strip.gsub('DATABASE_MAIN_URL=', '')

        if database_url.empty?
          puts "Failed to retrieve DATABASE_MAIN_URL for environment: #{@options.env}"
          exit 1
        end

        # Store the original URL for safety check
        original_url = database_url

        # Transform the database URL based on the mode
        database_url = transform_database_url(database_url)

        # Safety check: If attempting to use a read-only mode but URL didn't change,
        # the replica might not exist or pattern matching failed
        if @options.mode != 'rw' && database_url == original_url
          puts "Error: Attempted to connect to #{@options.mode} replica, but the connection URL"
          puts 'is identical to the main database URL. The replica may not exist.'
          exit 1
        end

        database_url
      else
        puts "Failed to retrieve DATABASE_MAIN_URL: #{stderr}"
        exit 1
      end
    end

    def transform_database_url(url)
      case @options.mode
      when 'ro', 'r1', 'primary'
        # Replace postgres-<name>. with postgres-<name>-replica-primary.
        @mode_display = '[RO-PRIMARY]'
        url.sub(/postgres-([^.]+)\./, 'postgres-\1-replica-primary.')
      when 'r2', 'secondary'
        # Replace postgres-<name>. with postgres-<name>-replica-secondary.
        @mode_display = '[RO-SECONDARY]'
        url.sub(/postgres-([^.]+)\./, 'postgres-\1-replica-secondary.')
      when 'r3', 'tertiary'
        # Replace postgres-<name>. with postgres-<name>-replica-tertiary.
        @mode_display = '[RO-TERTIARY]'
        url.sub(/postgres-([^.]+)\./, 'postgres-\1-replica-tertiary.')
      when 'rw'
        # Use the main database URL as is
        @mode_display = ''
        url
      else
        # For any custom mode, append it with a hyphen to the host name
        @mode_display = "[#{@options.mode}]"
        url.sub(/postgres-([^.]+)\./, "postgres-\\1-#{@options.mode}.")
      end
    end

    def extract_hostname(database_url)
      database_url.match(%r{postgres://(?:[^:@]+(?::[^@]*)?@)?([^:/]+)})[1]
    rescue StandardError
      'unknown host'
    end
  end
end
