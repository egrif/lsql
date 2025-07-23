require 'moneta'
require 'fileutils'

module LSQL
  class CacheManager
    TTL = 600 # 10 minutes in seconds
    CACHE_DIR = File.expand_path('~/.lsql_cache')

    def initialize
      # Ensure cache directory exists
      FileUtils.mkdir_p(CACHE_DIR) unless Dir.exist?(CACHE_DIR)
      
      # Use file-based store with expiration support
      @store = Moneta.new(:File, 
                         dir: CACHE_DIR, 
                         expires: true, 
                         default_expires: TTL)
    end

    def get(key)
      @store[key]
    end

    def set(key, value)
      @store[key] = value
    end

    def cached?(key)
      @store.key?(key)
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
