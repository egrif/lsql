# frozen_string_literal: true

require 'open3'
require 'set'
require_relative 'cache_manager'

module Lsql
  # Handles database URL retrieval and transformation
  class DatabaseConnector
    # Class-level cache to track pinged space/region combinations (thread-safe)
    @@pinged_combinations = Set.new
    @@ping_mutex = Mutex.new
    attr_reader :mode_display

    # Class method to reset pinged combinations cache (useful for testing or long sessions)
    def self.reset_ping_cache
      @@ping_mutex.synchronize do
        @@pinged_combinations.clear
      end
    end

    def initialize(options)
      @options = options
      @mode_display = ''

      # Calculate TTL in seconds if provided in minutes
      cache_ttl = @options.cache_ttl && (@options.cache_ttl * 60) # Convert minutes to seconds if provided

      @cache = LSQL::CacheManager.instance(@options.cache_prefix, cache_ttl)
    end

    def get_database_url
      # Ensure lotus is available for this space/region combination
      ensure_lotus_available

      # Check if URL is cached using all lotus parameters for uniqueness
      cached_url = nil
      if @cache.url_cached_for_params?(@options.space, @options.env, @options.region, @options.application)
        puts "Using cached database URL for #{@options.env} (space: #{@options.space}, region: #{@options.region}, app: #{@options.application})" if @options.verbose
        cached_url = @cache.get_cached_url_for_params(@options.space, @options.env, @options.region,
                                                      @options.application)
      else
        # Always get the main database URL - never use any other secret name
        cmd = "lotus secret get DATABASE_MAIN_URL -s \"#{@options.space}\" -e \"#{@options.env}\" -r \"#{@options.region}\" -a \"#{@options.application}\""
        stdout, stderr, status = Open3.capture3(cmd)

        if status.success?
          cached_url = stdout.strip.gsub('DATABASE_MAIN_URL=', '')

          if cached_url.empty?
            puts "Failed to retrieve DATABASE_MAIN_URL for environment: #{@options.env}"
            exit 1
          end

          # Cache the original URL with all parameters for uniqueness
          @cache.cache_url_for_params(@options.space, @options.env, @options.region, @options.application, cached_url)
          if @options.verbose
            puts "Cached database URL for #{@options.env} (space: #{@options.space}, region: #{@options.region}, app: #{@options.application}) - TTL: #{@cache.cache_stats[:ttl_seconds] / 60} minutes"
          end
        else
          puts "Failed to retrieve DATABASE_MAIN_URL: #{stderr}"
          exit 1
        end
      end

      # Store the original URL for safety check
      original_url = cached_url

      # Transform the database URL based on the mode
      database_url = transform_database_url(cached_url)

      # Safety check: If attempting to use a read-only mode but URL didn't change,
      # the replica might not exist or pattern matching failed
      if @options.mode != 'rw' && database_url == original_url
        puts "Error: Attempted to connect to #{@options.mode} replica, but the connection URL"
        puts 'is identical to the main database URL. The replica may not exist.'
        exit 1
      end

      database_url
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

    private

    # Ensure lotus is available by pinging it for the current space/region combination
    # Only pings once per space/region combination to avoid redundant calls (thread-safe)
    def ensure_lotus_available
      combination_key = "#{@options.space}_#{@options.region}"
      
      # Thread-safe check and update of pinged combinations
      should_ping = false
      
      @@ping_mutex.synchronize do
        unless @@pinged_combinations.include?(combination_key)
          # Mark immediately to prevent other threads from pinging
          @@pinged_combinations.add(combination_key)
          should_ping = true
        end
      end
      
      # Return early if another thread already pinged this combination
      return unless should_ping

      ping_cmd = "lotus ping -s #{@options.space} -r #{@options.region} > /dev/null 2>&1"
      
      puts "Ensuring lotus availability for space: #{@options.space}, region: #{@options.region}..." if @options.verbose
      
      _, _, status = Open3.capture3(ping_cmd)
      
      if status.success?
        puts "Lotus ping successful for #{@options.space}/#{@options.region}" if @options.verbose
      else
        puts "Warning: Lotus ping failed for #{@options.space}/#{@options.region}. Proceeding anyway..."
      end
    rescue StandardError => e
      puts "Warning: Error pinging lotus for #{@options.space}/#{@options.region}: #{e.message}"
    end
  end
end
