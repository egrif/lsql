# frozen_string_literal: true

require 'open3'
require 'set'
require_relative 'cache_manager'

module Lsql
  # Handles database URL retrieval and transformation
  class DatabaseConnector
    # Class-level cache to track pinged space/region combinations (thread-safe)
    @pinged_combinations = Set.new
    @ping_mutex = Mutex.new

    class << self
      attr_accessor :pinged_combinations, :ping_mutex
    end

    attr_reader :mode_display

    # Class method to reset pinged combinations cache (useful for testing or long sessions)
    def self.reset_ping_cache
      @ping_mutex.synchronize do
        @pinged_combinations.clear
      end
    end

    # Class method to pre-ping specific space/region combinations before parallel execution
    def self.ping_space_region_combinations(combinations, verbose: false)
      combinations.each do |space, region|
        combination_key = "#{space}_#{region}"

        # Thread-safe check to avoid duplicate pings
        should_ping = false
        @ping_mutex.synchronize do
          unless @pinged_combinations.include?(combination_key)
            @pinged_combinations.add(combination_key)
            should_ping = true
          end
        end

        next unless should_ping

        ping_cmd = "lotus ping -s #{space} -r #{region} > /dev/null 2>&1"
        puts "Pre-pinging lotus for space: #{space}, region: #{region}..." if verbose

        _, _, status = Open3.capture3(ping_cmd)

        if status.success?
          puts "Lotus ping successful for #{space}/#{region}" if verbose
        elsif verbose
          puts "Warning: Lotus ping failed for #{space}/#{region}. Proceeding anyway..."
        end
      rescue StandardError => e
        puts "Warning: Error pinging lotus for #{space}/#{region}: #{e.message}" if verbose
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
      # Check if URL is cached using all lotus parameters for uniqueness
      cached_url = nil
      if @cache.url_cached_for_params?(@options.space, @options.env, @options.region, @options.application, @options.cluster)
        puts "Using cached database URL for #{@options.env} (space: #{@options.space}, region: #{@options.region}, app: #{@options.application}, cluster: #{@options.cluster})" if @options.verbose
        cached_url = @cache.get_cached_url_for_params(@options.space, @options.env, @options.region,
                                                      @options.application, @options.cluster)

        # Validate cached URL - if it's invalid, clear it and fetch fresh
        unless cached_url && (cached_url.start_with?('postgres://') || cached_url.start_with?('postgresql://'))
          puts 'Warning: Invalid cached database URL detected. Clearing cache and fetching fresh URL.'
          @cache.clear_cache
          cached_url = nil
        end
      end

      if cached_url.nil?
        # Always get the main database URL - never use any other secret name
        cmd = build_lotus_command
        stdout, stderr, status = Open3.capture3(cmd)

        if status.success?
          # Extract the URL from stdout - look for the line starting with DATABASE_MAIN_URL=
          # Lotus may output installation messages, so we need to find the actual URL line
          # Try multiple possible formats
          url_line = stdout.lines.find { |line| line.strip.match?(/^DATABASE_MAIN_URL\s*[:=]/i) } ||
                     stdout.lines.find { |line| line.strip.start_with?('DATABASE_MAIN_URL=') }

          if url_line.nil?
            puts "Failed to retrieve DATABASE_MAIN_URL for environment: #{@options.env}"
            puts "Command executed: #{cmd}"
            puts 'Lotus stdout:'
            puts stdout
            puts 'Lotus stderr:' unless stderr.empty?
            puts stderr unless stderr.empty?
            exit 1
          end

          # Extract URL value, handling both = and : as separators
          cached_url = url_line.strip.sub(/^DATABASE_MAIN_URL\s*[:=]\s*/i, '').strip

          if cached_url.empty?
            puts "Failed to retrieve DATABASE_MAIN_URL for environment: #{@options.env}"
            puts "Command executed: #{cmd}"
            puts "Found URL line but it's empty: #{url_line.inspect}"
            puts 'Lotus stdout:'
            puts stdout
            exit 1
          end

          # Validate that we got a proper database URL (should start with postgres://)
          unless cached_url.start_with?('postgres://') || cached_url.start_with?('postgresql://')
            puts "Invalid database URL retrieved for environment: #{@options.env}"
            puts "Command executed: #{cmd}"
            puts "Extracted URL value: #{cached_url.inspect}"
            puts "URL line found: #{url_line.inspect}"
            puts 'Lotus stdout:'
            puts stdout
            puts 'Lotus stderr:' unless stderr.empty?
            puts stderr unless stderr.empty?
            exit 1
          end

          # Cache the original URL with all parameters for uniqueness
          @cache.cache_url_for_params(@options.space, @options.env, @options.region, @options.application, cached_url, @options.cluster)
          if @options.verbose
            puts "Cached database URL for #{@options.env} (space: #{@options.space}, region: #{@options.region}, app: #{@options.application}, cluster: #{@options.cluster}) - TTL: #{@cache.cache_stats[:ttl_seconds] / 60} minutes"
          end
        else
          puts 'Failed to retrieve DATABASE_MAIN_URL'
          puts "Command: #{cmd}"
          puts "Error: #{stderr}" unless stderr.empty?
          puts "Output: #{stdout}" unless stdout.empty?
          puts 'No error output from lotus command. Please check your lotus configuration.' if stderr.empty? && stdout.empty?
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

    # Check if lotus is available for this space/region combination
    # This should be called after pre-pinging has been done
    def ensure_lotus_available
      combination_key = "#{@options.space}_#{@options.region}"

      self.class.ping_mutex.synchronize do
        unless self.class.pinged_combinations.include?(combination_key)
          puts "Warning: Lotus not pre-pinged for #{@options.space}/#{@options.region}. Consider pre-pinging before parallel execution." if @options.verbose
          return false
        end
      end

      true
    end

    def build_lotus_command
      # Build lotus command - cluster replaces space and region
      cmd_parts = [
        'lotus secret get DATABASE_MAIN_URL',
        "-e \"#{@options.env}\"",
        "-a \"#{@options.application}\""
      ]

      if @options.cluster
        # When cluster is present, use cluster instead of space and region
        cmd_parts << "--cluster \"#{@options.cluster}\""
      else
        # When cluster is not present, use space and region
        cmd_parts << "-s \"#{@options.space}\""
        cmd_parts << "-r \"#{@options.region}\""
      end

      cmd_parts.join(' ')
    end
  end
end
