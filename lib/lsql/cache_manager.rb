require 'moneta'
require 'fileutils'

module LSQL
  class CacheManager
    TTL = 600 # 10 minutes in seconds
    CACHE_DIR = File.expand_path('~/.lsql_cache')

    def initialize
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
      Moneta.new(:File, 
                 dir: CACHE_DIR, 
                 expires: true, 
                 default_expires: TTL)
    end

    public

    def get(key)
      @store[key]
    end

    def set(key, value)
      if redis_store?
        @store.store(key, value, expires: TTL)
      else
        @store[key] = value
      end
    end

    def cached?(key)
      @store.key?(key)
    end

    def redis_store?
      @redis_enabled && @redis_connection_successful
    end

    def cache_key_for_url(environment)
      "db_url_#{environment}"
    end

    def get_cached_url(environment)
      key = cache_key_for_url(environment)
      get(key)
    end

    def cache_url(environment, url)
      key = cache_key_for_url(environment)
      set(key, url)
    end

    def url_cached?(environment)
      key = cache_key_for_url(environment)
      cached?(key)
    end

    def clear_cache
      @store.clear
    end

    def self.instance
      @instance ||= new
    end
  end
end
