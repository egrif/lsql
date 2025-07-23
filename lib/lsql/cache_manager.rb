require 'moneta'

module LSQL
  class CacheManager
    TTL = 600 # 10 minutes in seconds

    def initialize
      @store = Moneta.new(:Memory, expires: true, default_expires: TTL)
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
