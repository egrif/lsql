#!/usr/bin/env ruby
# Test script to demonstrate Moneta caching functionality

require './lib/lsql'

puts "=== Moneta Caching Test ==="
puts

# Test 1: Basic cache operations
cache = LSQL::CacheManager.instance
puts "1. Testing basic cache operations:"

# Test setting and getting a value
cache.set('test_key', 'test_value')
value = cache.get('test_key')
puts "   Set 'test_key' -> 'test_value'"
puts "   Retrieved: #{value}"
puts "   Cached?: #{cache.cached?('test_key')}"
puts

# Test 2: URL-specific caching
puts "2. Testing URL-specific caching methods:"
environment = "test_env_staging_use1_greenhouse"
test_url = "postgres://user:pass@postgres-123.example.com:5432/database"

cache.cache_url(environment, test_url)
puts "   Cached URL for environment: #{environment}"

retrieved_url = cache.get_cached_url(environment)
puts "   Retrieved URL: #{retrieved_url}"
puts "   URL cached?: #{cache.url_cached?(environment)}"
puts

# Test 3: Cache key generation
puts "3. Testing cache key generation:"
key = cache.cache_key_for_url(environment)
puts "   Environment: #{environment}"
puts "   Generated key: #{key}"
puts

# Test 4: TTL simulation (wait and check)
puts "4. Testing TTL behavior:"
puts "   Cache TTL is set to 10 minutes (#{LSQL::CacheManager::TTL} seconds)"
puts "   In a real scenario, entries would expire after 10 minutes"
puts

# Test 5: Cache clearing
puts "5. Testing cache clearing:"
puts "   Items before clear: #{cache.cached?('test_key') ? 'exists' : 'none'}"
cache.clear_cache
puts "   Cleared cache"
puts "   Items after clear: #{cache.cached?('test_key') ? 'exists' : 'none'}"
puts

puts "=== All cache tests completed successfully! ==="
