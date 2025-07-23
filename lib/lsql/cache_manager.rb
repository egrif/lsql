require 'moneta'
require 'fileutils'
require 'cgi'

module LSQL
  class CacheManager
    TTL = 600 # 10 minutes in seconds
    CACHE_DIR = File.expand_path('~/.lsql_cache')
    DEFAULT_CACHE_PREFIX = 'db_url'

    def initialize(cache_prefix = nil)
      @cache_prefix = cache_prefix || ENV['LSQL_CACHE_PREFIX'] || DEFAULT_CACHE_PREFIX
      @redis_enabled = !!ENV['REDIS_URL']
      @store = if @redis_enabled
                 create_redis_store
               else
                 create_file_store
               end
    end

    private

    def create_redis_store
      require 'redis'
      puts "Using Redis cache at #{ENV['REDIS_URL']}" if ENV['LSQL_VERBOSE']
      
      # Parse Redis URL
      uri = URI.parse(ENV['REDIS_URL'])
      redis_options = {
        host: uri.host,
        port: uri.port || 6379
      }
      redis_options[:password] = uri.password if uri.password
      
      store = Moneta.new(:Redis, redis_options.merge(expires: true))
      @redis_connection_successful = true
      store
    rescue LoadError
      puts "Warning: Redis gem not available, falling back to file cache"
      @redis_connection_successful = false
      create_file_store
    rescue => e
      puts "Warning: Failed to connect to Redis (#{e.message}), falling back to file cache"
      @redis_connection_successful = false
      create_file_store
    end

    def create_file_store
      # Ensure cache directory exists
      FileUtils.mkdir_p(CACHE_DIR) unless Dir.exist?(CACHE_DIR)
      
      puts "Using file cache at #{CACHE_DIR}" if ENV['LSQL_VERBOSE']
      
      @redis_connection_successful = false
      
      # Use file-based store with expiration support
      store = Moneta.new(:File, 
                         dir: CACHE_DIR, 
                         expires: true, 
                         default_expires: TTL)
      
      # Clean up expired entries on initialization
      cleanup_expired_entries(store)
      
      store
    end

    def cleanup_expired_entries(store)
      return unless store.is_a?(Moneta::Adapters::File)
      
      # Get all keys and check each one for expiration
      # This forces Moneta to check TTL and remove expired entries
      begin
        Dir.glob(File.join(CACHE_DIR, '*')).each do |file|
          next unless File.file?(file)
          
          # Extract key from filename (Moneta URL-encodes keys)
          key = File.basename(file)
          key = CGI.unescape(key) rescue key
          
          # Accessing the key will trigger TTL check and cleanup
          store.key?(key)
        end
        
        puts "Cleaned up expired cache entries" if ENV['LSQL_VERBOSE']
      rescue => e
        puts "Warning: Failed to cleanup expired entries: #{e.message}" if ENV['LSQL_VERBOSE']
      end
    end

    public

    def get(key)
      @store[key]
    end

    def set(key, value)
      if redis_store?
        @store.store(key, value, expires: TTL)
      else
        # For file store, use explicit expiration to ensure TTL works
        @store.store(key, value, expires: TTL)
      end
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
    def cache_url_for_params(space, env, region, application, url)
      composite_key = build_environment_key(space, env, region, application)
      cache_url(composite_key, url)
    end

    def get_cached_url_for_params(space, env, region, application)
      composite_key = build_environment_key(space, env, region, application)
      get_cached_url(composite_key)
    end

    def url_cached_for_params?(space, env, region, application)
      composite_key = build_environment_key(space, env, region, application)
      url_cached?(composite_key)
    end

    private

    def build_environment_key(space, env, region, application)
      "#{space}_#{env}_#{region}_#{application}"
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
        backend = "Redis"
      else
        # For file store, count files in cache directory
        pattern = File.join(CACHE_DIR, "lsql%3A#{@cache_prefix}%3A*")
        files = Dir.glob(pattern)
        total_keys = files.length
        backend = "File"
      end
      
      {
        backend: backend,
        prefix: @cache_prefix,
        total_entries: total_keys,
        ttl_seconds: TTL
      }
    end

    def self.instance(cache_prefix = nil)
      cache_prefix ||= ENV['LSQL_CACHE_PREFIX'] || DEFAULT_CACHE_PREFIX
      @instances ||= {}
      @instances[cache_prefix] ||= new(cache_prefix)
    end

    def self.clear_all_instances
      @instances = {}
    end
  end
end
