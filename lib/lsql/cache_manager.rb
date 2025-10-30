# frozen_string_literal: true

require 'moneta'
require 'fileutils'
require 'cgi'
require 'openssl'
require 'base64'
require 'digest'
require_relative 'config_manager'

module LSQL
  class CacheManager
    DEFAULT_TTL = 600 # 10 minutes in seconds (fallback)
    DEFAULT_CACHE_PREFIX = 'db_url'
    ENCRYPTION_ENV_VAR = 'LSQL_CACHE_KEY'

    def initialize(cache_prefix = nil, ttl_seconds = nil)
      @cache_prefix = cache_prefix || ENV['LSQL_CACHE_PREFIX'] || DEFAULT_CACHE_PREFIX
      @ttl = ttl_seconds || DEFAULT_TTL
      @cache_dir = ConfigManager.get_cache_directory(nil, ENV.fetch('LSQL_CACHE_DIR', nil))

      # Migrate legacy cache if needed
      ConfigManager.migrate_legacy_cache

      @redis_enabled = !ENV['REDIS_URL'].nil?
      @store = if @redis_enabled
                 create_redis_store
               else
                 create_file_store
               end
    end

    private

    def create_redis_store
      require 'redis'
      puts "Using Redis cache at #{ENV.fetch('REDIS_URL', nil)}" if ENV['LSQL_VERBOSE']

      # Parse Redis URL
      uri = URI.parse(ENV.fetch('REDIS_URL', nil))
      redis_options = {
        host: uri.host,
        port: uri.port || 6379
      }
      redis_options[:password] = uri.password if uri.password

      store = Moneta.new(:Redis, redis_options.merge(expires: true))
      @redis_connection_successful = true
      store
    rescue LoadError
      puts 'Warning: Redis gem not available, falling back to file cache'
      @redis_connection_successful = false
      create_file_store
    rescue StandardError => e
      puts "Warning: Failed to connect to Redis (#{e.message}), falling back to file cache"
      @redis_connection_successful = false
      create_file_store
    end

    def create_file_store
      # Ensure cache directory exists
      FileUtils.mkdir_p(@cache_dir)

      puts "Using file cache at #{@cache_dir}" if ENV['LSQL_VERBOSE']

      @redis_connection_successful = false

      # Use file-based store with expiration support
      store = Moneta.new(:File,
                         dir: @cache_dir,
                         expires: true,
                         default_expires: @ttl)

      # Clean up expired entries on initialization
      cleanup_expired_entries(store)

      store
    end

    def cleanup_expired_entries(store)
      return unless store.is_a?(Moneta::Adapters::File)

      # Get all keys and check each one for expiration
      # This forces Moneta to check TTL and remove expired entries
      begin
        Dir.glob(File.join(@cache_dir, '*')).each do |file|
          next unless File.file?(file)

          # Extract key from filename (Moneta URL-encodes keys)
          key = File.basename(file)
          key = begin
            CGI.unescape(key)
          rescue StandardError
            key
          end

          # Accessing the key will trigger TTL check and cleanup
          store.key?(key)
        end

        puts 'Cleaned up expired cache entries' if ENV['LSQL_VERBOSE']
      rescue StandardError => e
        puts "Warning: Failed to cleanup expired entries: #{e.message}" if ENV['LSQL_VERBOSE']
      end
    end

    # Encryption methods for file storage security
    def get_encryption_key
      # Get encryption key from environment variable
      key = ENV.fetch(ENCRYPTION_ENV_VAR, nil)
      return nil unless key

      # Ensure key is exactly 32 bytes for AES-256
      # Hash the provided key to get a consistent 32-byte key
      Digest::SHA256.digest(key)
    end

    def encrypt_value(value)
      return value if redis_store? # No encryption needed for Redis

      encryption_key = get_encryption_key
      return value unless encryption_key # No encryption if no key provided

      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.encrypt
      cipher.key = encryption_key

      # Generate random 12-byte IV for GCM mode
      iv = cipher.random_iv
      # For GCM mode, we need to ensure we use exactly 12 bytes
      iv = iv[0, 12] if iv.length > 12
      cipher.iv = iv

      # Encrypt the value
      encrypted = cipher.update(value) + cipher.final
      auth_tag = cipher.auth_tag

      # Combine IV + auth_tag + encrypted_data and encode as base64
      combined = iv + auth_tag + encrypted
      Base64.strict_encode64(combined)
    rescue StandardError => e
      puts "Warning: Encryption failed (#{e.message}), storing value unencrypted" if ENV['LSQL_VERBOSE']
      value
    end

    def decrypt_value(encrypted_value)
      return encrypted_value if redis_store? # No decryption needed for Redis

      encryption_key = get_encryption_key
      return encrypted_value unless encryption_key # No decryption if no key

      # Decode from base64
      combined = Base64.strict_decode64(encrypted_value)

      # Extract IV (12 bytes), auth_tag (16 bytes), and encrypted data
      iv = combined[0, 12]
      auth_tag = combined[12, 16]
      encrypted = combined[28..]

      # Decrypt
      decipher = OpenSSL::Cipher.new('AES-256-GCM')
      decipher.decrypt
      decipher.key = encryption_key
      decipher.iv = iv
      decipher.auth_tag = auth_tag

      decipher.update(encrypted) + decipher.final
    rescue StandardError => e
      puts "Warning: Decryption failed (#{e.message}), returning encrypted value" if ENV['LSQL_VERBOSE']
      encrypted_value
    end

    public

    def get(key)
      encrypted_value = @store[key]
      return nil unless encrypted_value

      decrypt_value(encrypted_value)
    end

    def set(key, value)
      encrypted_value = encrypt_value(value)

      if redis_store?
      else
        # For file store, use explicit expiration to ensure TTL works
      end
      @store.store(key, encrypted_value, expires: @ttl)
    end

    def cached?(key)
      @store.key?(key)
    end

    def redis_store?
      @redis_enabled && @redis_connection_successful
    end

    def cache_key_for_url(environment_composite)
      # environment_composite should be in format: "space_env_region_application"
      "lsql:#{@cache_prefix}:#{environment_composite}"
    end

    def get_cached_url(environment_composite)
      key = cache_key_for_url(environment_composite)
      get(key)
    end

    def cache_url(environment_composite, url)
      key = cache_key_for_url(environment_composite)
      set(key, url)
    end

    def url_cached?(environment_composite)
      key = cache_key_for_url(environment_composite)
      cached?(key)
    end

    # Convenience method that takes individual parameters
    def cache_url_for_params(space:, env:, region:, application:, url:, cluster: nil) # rubocop:disable Metrics/ParameterLists
      composite_key = build_environment_key(space, env, region, application, cluster)
      cache_url(composite_key, url)
    end

    def get_cached_url_for_params(space:, env:, region:, application:, cluster: nil)
      composite_key = build_environment_key(space, env, region, application, cluster)
      get_cached_url(composite_key)
    end

    def url_cached_for_params?(space:, env:, region:, application:, cluster: nil)
      composite_key = build_environment_key(space, env, region, application, cluster)
      url_cached?(composite_key)
    end

    private

    def build_environment_key(space, env, region, application, cluster = nil)
      key_parts = [space, env, region, application]
      key_parts << cluster if cluster
      key_parts.join('_')
    end

    public

    def clear_cache
      @store.clear
    end

    def cache_stats
      if redis_store?
        # For Redis, count keys with our prefix pattern
        redis_keys = `redis-cli keys "lsql:#{@cache_prefix}:*" 2>/dev/null`.split("\n").reject(&:empty?)
        total_keys = redis_keys.length
        backend = 'Redis'
        encryption_status = 'Not needed (Redis)'
        location = ENV['REDIS_URL'] || 'Redis'
      else
        # For file store, count files in cache directory
        pattern = File.join(@cache_dir, "lsql%3A#{@cache_prefix}%3A*")
        files = Dir.glob(pattern)
        total_keys = files.length
        backend = 'File'
        encryption_status = get_encryption_key ? 'Enabled' : 'Disabled (set LSQL_CACHE_KEY)'
        location = @cache_dir
      end

      {
        backend: backend,
        prefix: @cache_prefix,
        total_entries: total_keys,
        ttl_seconds: @ttl,
        encryption: encryption_status,
        location: location
      }
    end

    def self.instance(cache_prefix = nil, ttl_seconds = nil)
      # Use ConfigManager to resolve values with proper priority
      effective_prefix = LSQL::ConfigManager.get_cache_prefix(cache_prefix, ENV.fetch('LSQL_CACHE_PREFIX', nil))
      effective_ttl = if ttl_seconds
                        ttl_seconds
                      elsif ENV['LSQL_CACHE_TTL']
                        ENV['LSQL_CACHE_TTL'].to_i * 60 # Convert minutes to seconds
                      else
                        LSQL::ConfigManager.get_cache_ttl
                      end

      cache_key = "#{effective_prefix}_#{effective_ttl}"
      @instances ||= {}
      @instances[cache_key] ||= new(effective_prefix, effective_ttl)
    end

    def self.clear_all_instances
      @instances = {}
    end
  end
end
