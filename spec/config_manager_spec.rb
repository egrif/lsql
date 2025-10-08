# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe LSQL::ConfigManager do
  let(:test_config_dir) { Dir.mktmpdir('lsql_config_test') }
  let(:test_config_file) { File.join(test_config_dir, 'settings.yml') }

  before do
    # Mock the config directory and file paths
    stub_const('LSQL::ConfigManager::CONFIG_DIR', test_config_dir)
    stub_const('LSQL::ConfigManager::CONFIG_FILE', test_config_file)
    # Mock the default config to use test directory
    stub_const('LSQL::ConfigManager::DEFAULT_CONFIG', {
      'cache' => {
        'prefix' => 'db_url',
        'ttl_minutes' => 10,
        'directory' => File.join(test_config_dir, 'cache')
      }
    }.freeze)
  end

  after do
    FileUtils.rm_rf(test_config_dir)
    # Clean up environment variables
    ENV.delete('LSQL_CACHE_PREFIX')
    ENV.delete('LSQL_CACHE_TTL')
    ENV.delete('LSQL_CACHE_DIR')
  end

  describe '.load_config' do
    context 'when config file exists' do
      before do
        FileUtils.mkdir_p(test_config_dir)
        File.write(test_config_file, {
          'cache' => {
            'prefix' => 'test_prefix',
            'ttl_minutes' => 20,
            'directory' => '/custom/cache/dir'
          }
        }.to_yaml)
      end

      it 'loads configuration from file' do
        config = described_class.load_config

        expect(config['cache']['prefix']).to eq('test_prefix')
        expect(config['cache']['ttl_minutes']).to eq(20)
        expect(config['cache']['directory']).to eq('/custom/cache/dir')
      end
    end

    context 'when config file does not exist' do
      it 'returns default config' do
        config = described_class.load_config
        expect(config).to include('cache', 'groups', 'defaults')
        expect(config['cache']['prefix']).to eq('db_url')
        expect(config['cache']['ttl_minutes']).to eq(480)
      end
    end

    context 'when config file is invalid YAML' do
      before do
        FileUtils.mkdir_p(test_config_dir)
        File.write(test_config_file, 'invalid: yaml: content: [')
      end

      it 'returns default config and warns' do
        config = nil
        expect { config = described_class.load_config }.to output(/Warning: Failed to load config file/).to_stdout
        expect(config).to include('cache', 'groups', 'defaults')
      end
    end
  end

  describe '.get_cache_prefix' do
    it 'returns explicit value when provided' do
      result = described_class.get_cache_prefix('explicit_prefix', 'env_prefix')
      expect(result).to eq('explicit_prefix')
    end

    it 'returns environment value when explicit not provided' do
      result = described_class.get_cache_prefix(nil, 'env_prefix')
      expect(result).to eq('env_prefix')
    end

    it 'returns config file value when explicit and env not provided' do
      FileUtils.mkdir_p(test_config_dir)
      File.write(test_config_file, {
        'cache' => { 'prefix' => 'config_prefix' }
      }.to_yaml)

      result = described_class.get_cache_prefix(nil, nil)
      expect(result).to eq('config_prefix')
    end

    it 'returns default when no other values provided' do
      result = described_class.get_cache_prefix(nil, nil)
      expect(result).to eq('db_url')
    end
  end

  describe '.get_cache_ttl' do
    it 'returns explicit value when provided' do
      result = described_class.get_cache_ttl(1800, 900)
      expect(result).to eq(1800)
    end

    it 'returns environment value when explicit not provided' do
      result = described_class.get_cache_ttl(nil, 900)
      expect(result).to eq(900)
    end

    it 'returns config file value converted to seconds' do
      FileUtils.mkdir_p(test_config_dir)
      File.write(test_config_file, {
        'cache' => { 'ttl_minutes' => 15 }
      }.to_yaml)

      result = described_class.get_cache_ttl(nil, nil)
      expect(result).to eq(900) # 15 minutes * 60 seconds
    end

    it 'returns default when no other values provided' do
      result = described_class.get_cache_ttl(nil, nil)
      expect(result).to eq(28_800) # 480 minutes * 60 seconds
    end
  end

  describe '.get_cache_directory' do
    it 'returns expanded explicit value when provided' do
      result = described_class.get_cache_directory('/custom/cache', nil)
      expect(result).to eq('/custom/cache')
    end

    it 'returns expanded environment value when explicit not provided' do
      result = described_class.get_cache_directory(nil, '~/env/cache')
      expect(result).to eq(File.expand_path('~/env/cache'))
    end

    it 'returns config file value when explicit and env not provided' do
      FileUtils.mkdir_p(test_config_dir)
      File.write(test_config_file, {
        'cache' => { 'directory' => '/config/cache/dir' }
      }.to_yaml)

      result = described_class.get_cache_directory(nil, nil)
      expect(result).to eq('/config/cache/dir')
    end

    it 'returns default when no other values provided' do
      result = described_class.get_cache_directory(nil, nil)
      expected_default = File.expand_path('~/.lsql/cache')
      expect(result).to eq(expected_default)
    end

    it 'expands tilde in paths' do
      result = described_class.get_cache_directory('~/my/cache', nil)
      expect(result).to eq(File.expand_path('~/my/cache'))
    end
  end

  describe '.migrate_legacy_cache' do
    let(:old_cache_dir) { File.join(test_config_dir, 'old_cache') }
    let(:new_cache_dir) { File.join(test_config_dir, 'new_cache') }

    before do
      allow(described_class).to receive(:get_cache_directory).and_return(new_cache_dir)
    end

    context 'when legacy cache directory exists' do
      before do
        FileUtils.mkdir_p(old_cache_dir)
        File.write(File.join(old_cache_dir, 'cache_file1'), 'content1')
        File.write(File.join(old_cache_dir, 'cache_file2'), 'content2')
      end

      it 'migrates files from old to new location' do
        skip 'Migration testing requires complex mocking - tested in integration'
      end

      it 'removes old directory when empty after migration' do
        skip 'Migration testing requires complex mocking - tested in integration'
      end

      it 'does not overwrite existing files in new location' do
        FileUtils.mkdir_p(new_cache_dir)
        File.write(File.join(new_cache_dir, 'cache_file1'), 'existing_content')

        described_class.migrate_legacy_cache

        expect(File.read(File.join(new_cache_dir, 'cache_file1'))).to eq('existing_content')
        expect(File.exist?(File.join(old_cache_dir, 'cache_file1'))).to be true # Not moved
      end
    end

    context 'when legacy cache directory does not exist' do
      it 'does nothing' do
        expect { described_class.migrate_legacy_cache }.not_to output.to_stdout
        expect(Dir.exist?(new_cache_dir)).to be false
      end
    end

    context 'when old and new directories are the same' do
      before do
        allow(described_class).to receive(:get_cache_directory).and_return(old_cache_dir)
        FileUtils.mkdir_p(old_cache_dir)
      end

      it 'does nothing' do
        expect { described_class.migrate_legacy_cache }.not_to output.to_stdout
      end
    end
  end

  describe '.create_default_config' do
    it 'creates default config file when it does not exist' do
      expect { described_class.create_default_config }.to output(/Created user config file/).to_stdout

      expect(File.exist?(test_config_file)).to be true
      content = File.read(test_config_file)
      expect(content).to include('# cache:')
      expect(content).to include('myteam_db_urls')
      expect(content).to include('ttl_minutes: 30')
      expect(content).to include('directory:')
    end

    it 'does not overwrite existing config file' do
      FileUtils.mkdir_p(test_config_dir)
      File.write(test_config_file, 'existing content')

      expect { described_class.create_default_config }.to_not output.to_stdout

      expect(File.read(test_config_file)).to eq('existing content')
    end

    it 'creates directory structure if needed' do
      expect { described_class.create_default_config }.to output(/Created user config file/).to_stdout

      expect(Dir.exist?(test_config_dir)).to be true
      expect(File.exist?(test_config_file)).to be true
    end

    it 'includes cache directory in default config' do
      expect { described_class.create_default_config }.to output(/Created user config file/).to_stdout

      content = File.read(test_config_file)
      expect(content).to include('directory: ~/.lsql/cache')
      expect(content).to include('# groups:')
    end
  end

  describe 'priority system' do
    before do
      ENV['LSQL_CACHE_PREFIX'] = 'env_prefix'
      ENV['LSQL_CACHE_TTL'] = '20'
      ENV['LSQL_CACHE_DIR'] = '/env/cache'

      FileUtils.mkdir_p(test_config_dir)
      File.write(test_config_file, {
        'cache' => {
          'prefix' => 'config_prefix',
          'ttl_minutes' => 30,
          'directory' => '/config/cache'
        }
      }.to_yaml)
    end

    it 'prioritizes explicit values over environment and config' do
      prefix = described_class.get_cache_prefix('explicit_prefix', ENV.fetch('LSQL_CACHE_PREFIX', nil))
      ttl = described_class.get_cache_ttl(1800, ENV['LSQL_CACHE_TTL'].to_i * 60)
      directory = described_class.get_cache_directory('/explicit/cache', ENV.fetch('LSQL_CACHE_DIR', nil))

      expect(prefix).to eq('explicit_prefix')
      expect(ttl).to eq(1800)
      expect(directory).to eq('/explicit/cache')
    end

    it 'prioritizes environment values over config file' do
      prefix = described_class.get_cache_prefix(nil, ENV.fetch('LSQL_CACHE_PREFIX', nil))
      ttl = described_class.get_cache_ttl(nil, ENV['LSQL_CACHE_TTL'].to_i * 60)
      directory = described_class.get_cache_directory(nil, ENV.fetch('LSQL_CACHE_DIR', nil))

      expect(prefix).to eq('env_prefix')
      expect(ttl).to eq(1200) # 20 minutes * 60
      expect(directory).to eq('/env/cache')
    end

    it 'uses config file values when explicit and environment not provided' do
      prefix = described_class.get_cache_prefix(nil, nil)
      ttl = described_class.get_cache_ttl(nil, nil)
      directory = described_class.get_cache_directory(nil, nil)

      expect(prefix).to eq('config_prefix')
      expect(ttl).to eq(1800) # 30 minutes * 60
      expect(directory).to eq('/config/cache')
    end
  end

  describe 'prompt configuration' do
    describe '.get_prompt_config' do
      it 'returns default prompt config when no user config exists' do
        config = described_class.get_prompt_config
        expect(config).to include('colors', 'production_patterns', 'templates')
      end
    end

    describe '.get_prompt_colors' do
      it 'returns default colors' do
        colors = described_class.get_prompt_colors
        expect(colors['production']).to eq("\u000033[0;31m")
        expect(colors['development']).to eq("\u000033[0;32m")
        expect(colors['reset']).to eq("\u000033[0m")
      end
    end

    describe '.get_production_patterns' do
      it 'returns default production patterns' do
        patterns = described_class.get_production_patterns
        expect(patterns).to include('^prod', '^production')
      end
    end

    describe '.get_prompt_templates' do
      it 'returns default prompt templates' do
        templates = described_class.get_prompt_templates
        expect(templates['colored']).to include('{color}', '{env}', '{mode}', '{reset}')
        expect(templates['plain']).to include('{space}', '{mode_short}', '{env}', '{mode}')
      end
    end

    describe '.is_production_environment?' do
      it 'detects production environments correctly' do
        expect(described_class.is_production_environment?('prod01')).to be true
        expect(described_class.is_production_environment?('production')).to be true
        expect(described_class.is_production_environment?('PROD-TEST')).to be true
        expect(described_class.is_production_environment?('staging01')).to be false
        expect(described_class.is_production_environment?('dev01')).to be false
      end
    end
  end
end
