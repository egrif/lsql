# frozen_string_literal: true

require 'spec_helper'
require 'lsql/database_connector'

RSpec.describe Lsql::DatabaseConnector do
  let(:options) do
    double(
      'options',
      space: 'prod',
      region: 'use1',
      env: 'test',
      application: 'myapp',
      verbose: false,
      cache_ttl: 10,
      cache_prefix: 'test',
      database: nil
    )
  end

  let(:connector) { described_class.new(options) }

  before do
    # Reset the ping cache before each test
    described_class.reset_ping_cache
  end

  describe '.ping_space_region_combinations' do
    it 'pings lotus with the correct space and region parameters' do
      combinations = [%w[prod use1]]
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: true)])

      described_class.ping_space_region_combinations(combinations)
    end

    it 'only pings once for the same space/region combination' do
      combinations = [%w[prod use1], %w[prod use1]]

      # Should only ping once even though combination is listed twice
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      described_class.ping_space_region_combinations(combinations)
    end

    it 'pings separately for different space/region combinations' do
      combinations = [%w[prod use1], %w[dev euc1]]

      # Should ping for first combination
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      # Should ping for second combination
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s dev -r euc1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      described_class.ping_space_region_combinations(combinations)
    end

    it 'handles ping failures gracefully and continues' do
      combinations = [%w[prod use1]]
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: false)])

      # Should not raise an error
      expect { described_class.ping_space_region_combinations(combinations) }.not_to raise_error
    end

    it 'handles ping exceptions gracefully' do
      combinations = [%w[prod use1]]
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_raise(StandardError, 'Connection failed')

      # Should not raise an error
      expect { described_class.ping_space_region_combinations(combinations) }.not_to raise_error
    end
  end

  describe '#ensure_lotus_available' do
    it 'returns true when combination has been pre-pinged' do
      # Pre-ping the combination
      described_class.ping_space_region_combinations([%w[prod use1]])

      expect(connector.send(:ensure_lotus_available)).to be true
    end

    it 'returns false when combination has not been pre-pinged' do
      expect(connector.send(:ensure_lotus_available)).to be false
    end
  end

  describe '.reset_ping_cache' do
    it 'clears the pinged combinations cache' do
      # Ping once to populate cache
      allow(Open3).to receive(:capture3).and_return([nil, nil, double('status', success?: true)])
      described_class.ping_space_region_combinations([%w[prod use1]])

      # Verify cache is populated
      expect(connector.send(:ensure_lotus_available)).to be true

      # Reset cache
      described_class.reset_ping_cache

      # Verify cache is cleared
      expect(connector.send(:ensure_lotus_available)).to be false
    end
  end

  describe '#override_database_name' do
    it 'returns original URL when database_name is nil' do
      url = 'postgres://user:pass@host:5432/original_db'
      result = connector.override_database_name(url, nil)
      expect(result).to eq(url)
    end

    it 'returns original URL when database_name is empty' do
      url = 'postgres://user:pass@host:5432/original_db'
      result = connector.override_database_name(url, '')
      expect(result).to eq(url)
    end

    it 'overrides database name in postgres:// URL' do
      url = 'postgres://user:pass@host:5432/original_db'
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq('postgres://user:pass@host:5432/new_db')
    end

    it 'overrides database name in postgresql:// URL' do
      url = 'postgresql://user:pass@host:5432/original_db'
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq('postgresql://user:pass@host:5432/new_db')
    end

    it 'preserves query parameters when overriding database name' do
      url = 'postgres://user:pass@host:5432/original_db?sslmode=require&connect_timeout=10'
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq('postgres://user:pass@host:5432/new_db?sslmode=require&connect_timeout=10')
    end

    it 'handles URL without database name' do
      url = 'postgres://user:pass@host:5432'
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq('postgres://user:pass@host:5432/new_db')
    end

    it 'handles URL without database name but with query parameters' do
      url = 'postgres://user:pass@host:5432?sslmode=require'
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq('postgres://user:pass@host:5432/new_db?sslmode=require')
    end

    it 'returns original URL for malformed URLs' do
      url = 'not-a-valid-url'
      expect { connector.override_database_name(url, 'new_db') }.to output(/Warning: Unable to parse database URL format/).to_stdout
      result = connector.override_database_name(url, 'new_db')
      expect(result).to eq(url)
    end
  end
end
