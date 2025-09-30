# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lsql do
  it 'has a version number' do
    expect(Lsql::VERSION).not_to be nil
    expect(Lsql::VERSION).to be_a(String)
    expect(Lsql::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end

RSpec.describe Lsql::Application do
  describe '#initialize' do
    it 'creates a new application instance' do
      app = described_class.new
      expect(app).to be_an_instance_of(described_class)
    end
  end

  describe '#run' do
    let(:app) { described_class.new }

    it 'handles --help flag' do
      expect do
        expect { app.run(['--help']) }.to output.to_stdout
      end.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    end

    it 'handles invalid arguments gracefully' do
      expect do
        expect { app.run(['--invalid-flag']) }.to output(/Error:.*invalid/).to_stdout
      end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    it 'handles show-config option' do
      expect { app.run(['--show-config']) }.to output(/Configuration/).to_stdout
    end

    it 'handles init-config option' do
      expect { app.run(['--init-config']) }.to output(/Configuration file created/).to_stdout
    end
  end
end

RSpec.describe Lsql::CommandLineParser do
  let(:parser) { described_class.new }

  describe '#parse' do
    it 'parses environment option' do
      options = parser.parse(['-e', 'test'])
      expect(options.env).to eq('test')
    end

    it 'parses group option' do
      options = parser.parse(['-g', 'staging'])
      expect(options.group).to eq('staging')
    end

    it 'defaults to parallel execution (auto-detect cores)' do
      options = parser.parse(['-e', 'test'])
      expect(options.parallel).to eq(0)
    end

    it 'parses no-parallel option' do
      options = parser.parse(['-e', 'test', '-P'])
      expect(options.parallel).to be false
    end

    it 'parses parallel option with threads' do
      options = parser.parse(['-e', 'test', '-p', '4'])
      expect(options.parallel).to eq(4)
    end

    it 'parses parallel option without threads (auto-detect)' do
      options = parser.parse(['-e', 'test', '-p'])
      expect(options.parallel).to eq(0)
    end

    it 'handles cache options' do
      options = parser.parse(['-e', 'test', '--cache-prefix', 'test', '--cache-ttl', '20'])
      expect(options.cache_prefix).to eq('test')
      expect(options.cache_ttl).to eq(20)
    end

    it 'handles show-config option' do
      options = parser.parse(['--show-config'])
      expect(options.show_config).to be true
    end

    it 'handles init-config option' do
      options = parser.parse(['--init-config'])
      expect(options.init_config).to be true
    end
  end
end

RSpec.describe LSQL::ConfigManager do
  describe '.get_cache_prefix' do
    it 'returns explicit value when provided' do
      result = LSQL::ConfigManager.get_cache_prefix('explicit')
      expect(result).to eq('explicit')
    end

    it 'returns default when no value provided' do
      result = LSQL::ConfigManager.get_cache_prefix
      expect(result).to eq('db_url')
    end
  end

  describe '.get_cache_ttl' do
    it 'returns TTL in seconds' do
      result = LSQL::ConfigManager.get_cache_ttl
      expect(result).to be_a(Integer)
      expect(result).to eq(600) # 10 minutes in seconds
    end
  end
end
