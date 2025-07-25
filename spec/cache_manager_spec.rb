# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe LSQL::CacheManager do
  let(:test_cache_dir) { Dir.mktmpdir('lsql_cache_test') }
  let(:test_prefix) { 'test_prefix' }
  let(:test_ttl) { 300 } # 5 minutes

  before do
    # Clear any existing instances
    described_class.clear_all_instances
    # Mock the config manager to use our test directory
    allow(LSQL::ConfigManager).to receive(:get_cache_directory).and_return(test_cache_dir)
    allow(LSQL::ConfigManager).to receive(:migrate_legacy_cache)
  end

  after do
    FileUtils.rm_rf(test_cache_dir) if Dir.exist?(test_cache_dir)
    # Clear environment variables
    ENV.delete('LSQL_CACHE_KEY')
    ENV.delete('REDIS_URL')
    described_class.clear_all_instances
  end

  describe '#initialize' do
    context 'with file backend' do
      it 'creates cache directory if it does not exist' do
        cache_dir = File.join(test_cache_dir, 'new_subdir')
        allow(LSQL::ConfigManager).to receive(:get_cache_directory).and_return(cache_dir)
        
        described_class.new(test_prefix, test_ttl)
        
        expect(Dir.exist?(cache_dir)).to be true
      end

      it 'calls migration method' do
        expect(LSQL::ConfigManager).to receive(:migrate_legacy_cache)
        described_class.new(test_prefix, test_ttl)
      end
    end

    context 'with Redis backend' do
      before do
        ENV['REDIS_URL'] = 'redis://localhost:6379'
      end

      it 'attempts to create Redis store' do
        # Mock Redis to avoid actual connection
        allow_any_instance_of(described_class).to receive(:create_redis_store).and_return(double('redis_store'))
        
        cache_manager = described_class.new(test_prefix, test_ttl)
        expect(cache_manager.instance_variable_get(:@redis_enabled)).to be true
      end
    end
  end

  describe 'cache operations' do
    let(:cache_manager) { described_class.new(test_prefix, test_ttl) }
    let(:test_key) { 'test_key' }
    let(:test_value) { 'postgresql://user:pass@host:5432/db' }

    describe '#set and #get' do
      it 'stores and retrieves values' do
        cache_manager.set(test_key, test_value)
        retrieved_value = cache_manager.get(test_key)
        
        expect(retrieved_value).to eq(test_value)
      end

      it 'returns nil for non-existent keys' do
        result = cache_manager.get('non_existent_key')
        expect(result).to be_nil
      end

      it 'respects TTL expiration' do
        short_ttl_manager = described_class.new(test_prefix, 1) # 1 second TTL
        short_ttl_manager.set(test_key, test_value)
        
        expect(short_ttl_manager.get(test_key)).to eq(test_value)
        
        sleep(2) # Wait for expiration
        expect(short_ttl_manager.get(test_key)).to be_nil
      end
    end

    describe '#clear_cache' do
      it 'removes all cache entries with matching prefix' do
        cache_manager.set('key1', 'value1')
        cache_manager.set('key2', 'value2')
        
        expect(cache_manager.get('key1')).to eq('value1')
        expect(cache_manager.get('key2')).to eq('value2')
        
        cache_manager.clear_cache
        
        expect(cache_manager.get('key1')).to be_nil
        expect(cache_manager.get('key2')).to be_nil
      end

      it 'clears all entries in the cache store' do
        other_manager = described_class.new('other_prefix', test_ttl)
        
        cache_manager.set('key1', 'value1')
        other_manager.set('key2', 'value2')
        
        cache_manager.clear_cache
        
        expect(cache_manager.get('key1')).to be_nil
        # Note: clear_cache clears the entire store, not just the prefix
        expect(other_manager.get('key2')).to be_nil
      end
    end
  end

  describe 'encryption features' do
    let(:cache_manager) { described_class.new(test_prefix, test_ttl) }
    let(:encryption_key) { 'test-encryption-key-123' }
    let(:test_key) { 'encrypted_test_key' }
    let(:test_value) { 'postgresql://user:secret@host:5432/secure_db' }

    before do
      # Ensure we're testing file storage, not Redis
      ENV.delete('REDIS_URL')
    end

    describe 'with encryption enabled' do
      before do
        ENV['LSQL_CACHE_KEY'] = encryption_key
      end

      it 'encrypts values when storing' do
        cache_manager.set(test_key, test_value)
        
        # Read the raw file content to verify it's encrypted
        cache_files = Dir.glob(File.join(test_cache_dir, '*'))
        expect(cache_files).not_to be_empty
        
        raw_content = File.read(cache_files.first)
        expect(raw_content).not_to include(test_value) # Original value should not be visible
        expect(raw_content).not_to include('postgresql://') # Protocol should not be visible
      end

      it 'decrypts values when retrieving' do
        cache_manager.set(test_key, test_value)
        retrieved_value = cache_manager.get(test_key)
        
        expect(retrieved_value).to eq(test_value)
      end

      it 'handles encryption key changes gracefully' do
        cache_manager.set(test_key, test_value)
        expect(cache_manager.get(test_key)).to eq(test_value)
        
        # Change encryption key
        ENV['LSQL_CACHE_KEY'] = 'different-key'
        new_manager = described_class.new(test_prefix, test_ttl)
        
        # Should return the encrypted data (can't decrypt with wrong key)
        result = new_manager.get(test_key)
        expect(result).not_to be_nil
        expect(result).not_to eq(test_value) # Should not be the original value
        expect(result).to be_a(String) # Should be the encrypted string
      end
    end

    describe 'without encryption' do
      before do
        ENV.delete('LSQL_CACHE_KEY')
      end

      it 'stores values unencrypted' do
        cache_manager.set(test_key, test_value)
        
        # Read the raw file content to verify it contains the original value
        cache_files = Dir.glob(File.join(test_cache_dir, '*'))
        expect(cache_files).not_to be_empty
        
        raw_content = File.read(cache_files.first)
        expect(raw_content).to include(test_value)
      end

      it 'can read unencrypted values when encryption is later enabled' do
        # Store without encryption
        cache_manager.set(test_key, test_value)
        expect(cache_manager.get(test_key)).to eq(test_value)
        
        # Enable encryption
        ENV['LSQL_CACHE_KEY'] = encryption_key
        encrypted_manager = described_class.new(test_prefix, test_ttl)
        
        # Should still be able to read unencrypted data
        expect(encrypted_manager.get(test_key)).to eq(test_value)
      end
    end
  end

  describe '#cache_stats' do
    let(:cache_manager) { described_class.new(test_prefix, test_ttl) }

    context 'with file backend' do
      it 'returns correct stats without encryption' do
        # Use proper cache keys that match the expected pattern
        cache_manager.set('lsql:test_prefix:key1', 'value1')
        cache_manager.set('lsql:test_prefix:key2', 'value2')
        
        stats = cache_manager.cache_stats
        
        expect(stats[:backend]).to eq('File')
        expect(stats[:prefix]).to eq(test_prefix)
        expect(stats[:total_entries]).to eq(2)
        expect(stats[:ttl_seconds]).to eq(test_ttl)
        expect(stats[:encryption]).to eq('Disabled (set LSQL_CACHE_KEY)')
        expect(stats[:location]).to eq(test_cache_dir)
      end

      it 'returns correct stats with encryption' do
        ENV['LSQL_CACHE_KEY'] = 'test-key'
        encrypted_manager = described_class.new(test_prefix, test_ttl)
        
        encrypted_manager.set('key1', 'value1')
        
        stats = encrypted_manager.cache_stats
        
        expect(stats[:backend]).to eq('File')
        expect(stats[:encryption]).to eq('Enabled')
        expect(stats[:location]).to eq(test_cache_dir)
      end
    end

    context 'with Redis backend' do
      before do
        ENV['REDIS_URL'] = 'redis://localhost:6379'
        # Mock Redis to avoid actual connection
        redis_store = double('redis_store')
        allow_any_instance_of(described_class).to receive(:create_redis_store).and_return(redis_store)
        allow_any_instance_of(described_class).to receive(:redis_store?).and_return(true)
      end

      it 'returns correct stats for Redis' do
        # Mock redis-cli command
        allow_any_instance_of(described_class).to receive(:`).and_return("key1\nkey2\n")
        
        stats = cache_manager.cache_stats
        
        expect(stats[:backend]).to eq('Redis')
        expect(stats[:encryption]).to eq('Not needed (Redis)')
        expect(stats[:location]).to eq('redis://localhost:6379')
      end
    end
  end

  describe '.instance' do
    it 'returns singleton instances based on prefix and TTL' do
      instance1 = described_class.instance('prefix1', 300)
      instance2 = described_class.instance('prefix1', 300)
      instance3 = described_class.instance('prefix2', 300)
      
      expect(instance1).to be(instance2) # Same instance
      expect(instance1).not_to be(instance3) # Different instance
    end

    it 'uses ConfigManager for default values' do
      expect(LSQL::ConfigManager).to receive(:get_cache_prefix).and_return('config_prefix')
      expect(LSQL::ConfigManager).to receive(:get_cache_ttl).and_return(600)
      
      instance = described_class.instance
      
      expect(instance.instance_variable_get(:@cache_prefix)).to eq('config_prefix')
      expect(instance.instance_variable_get(:@ttl)).to eq(600)
    end
  end

  describe 'private encryption methods' do
    let(:cache_manager) { described_class.new(test_prefix, test_ttl) }
    let(:test_data) { 'sensitive database connection string' }

    before do
      # Ensure we're testing file storage, not Redis
      ENV.delete('REDIS_URL')
    end

    describe '#get_encryption_key' do
      it 'returns nil when no key is set' do
        ENV.delete('LSQL_CACHE_KEY')
        key = cache_manager.send(:get_encryption_key)
        expect(key).to be_nil
      end

      it 'returns hashed key when environment variable is set' do
        ENV['LSQL_CACHE_KEY'] = 'my-secret-key'
        key = cache_manager.send(:get_encryption_key)
        
        expect(key).not_to be_nil
        expect(key.length).to eq(32) # SHA-256 produces 32-byte hash
        expect(key).to be_a(String)
      end

      it 'returns consistent key for same input' do
        ENV['LSQL_CACHE_KEY'] = 'consistent-key'
        key1 = cache_manager.send(:get_encryption_key)
        key2 = cache_manager.send(:get_encryption_key)
        
        expect(key1).to eq(key2)
      end
    end

    describe '#encrypt_value and #decrypt_value' do
      before do
        ENV['LSQL_CACHE_KEY'] = 'test-encryption-key'
      end

      it 'encrypts and decrypts data correctly' do
        encrypted = cache_manager.send(:encrypt_value, test_data)
        decrypted = cache_manager.send(:decrypt_value, encrypted)
        
        expect(encrypted).not_to eq(test_data) # Should be different
        expect(encrypted).to be_a(String)
        expect(decrypted).to eq(test_data)
      end

      it 'produces different encrypted output for same input (unique IV)' do
        encrypted1 = cache_manager.send(:encrypt_value, test_data)
        encrypted2 = cache_manager.send(:encrypt_value, test_data)
        
        expect(encrypted1).not_to eq(encrypted2) # Unique IV makes each encryption different
        
        # But both should decrypt to same value
        decrypted1 = cache_manager.send(:decrypt_value, encrypted1)
        decrypted2 = cache_manager.send(:decrypt_value, encrypted2)
        
        expect(decrypted1).to eq(test_data)
        expect(decrypted2).to eq(test_data)
      end

      it 'handles decryption errors gracefully' do
        invalid_encrypted_data = 'invalid-base64-data'
        result = cache_manager.send(:decrypt_value, invalid_encrypted_data)
        
        expect(result).to eq(invalid_encrypted_data) # Returns original on error
      end

      it 'returns original value when no encryption key is available' do
        ENV.delete('LSQL_CACHE_KEY')
        no_key_manager = described_class.new(test_prefix, test_ttl)
        
        encrypted = no_key_manager.send(:encrypt_value, test_data)
        expect(encrypted).to eq(test_data) # No encryption, returns original
        
        decrypted = no_key_manager.send(:decrypt_value, test_data)
        expect(decrypted).to eq(test_data) # No decryption, returns original
      end
    end
  end

  describe 'configuration integration' do
    it 'uses custom cache directory from environment variable' do
      custom_dir = File.join(test_cache_dir, 'custom')
      allow(LSQL::ConfigManager).to receive(:get_cache_directory).and_return(custom_dir)
      
      cache_manager = described_class.new(test_prefix, test_ttl)
      cache_manager.set('test_key', 'test_value')
      
      expect(Dir.exist?(custom_dir)).to be true
      expect(cache_manager.cache_stats[:location]).to eq(custom_dir)
    end

    it 'handles cache directory creation errors gracefully' do
      # Mock FileUtils to simulate permission error
      allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES.new('Permission denied'))
      
      expect {
        described_class.new(test_prefix, test_ttl)
      }.to raise_error(Errno::EACCES)
    end
  end
end
