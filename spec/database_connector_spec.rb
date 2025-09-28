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
      cache_prefix: 'test'
    )
  end

  let(:connector) { described_class.new(options) }

  before do
    # Reset the ping cache before each test
    described_class.reset_ping_cache
  end

  describe '#ensure_lotus_available' do
    it 'pings lotus with the correct space and region parameters' do
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: true)])

      # Call the private method using send
      connector.send(:ensure_lotus_available)
    end

    it 'only pings once for the same space/region combination' do
      # First call should ping
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      # Call twice with same space/region
      connector.send(:ensure_lotus_available)
      connector.send(:ensure_lotus_available)
    end

    it 'pings separately for different space/region combinations' do
      options2 = double(
        'options2',
        space: 'dev',
        region: 'euc1',
        env: 'test2',
        application: 'myapp',
        verbose: false,
        cache_ttl: 10,
        cache_prefix: 'test'
      )
      connector2 = described_class.new(options2)

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

      connector.send(:ensure_lotus_available)
      connector2.send(:ensure_lotus_available)
    end

    it 'handles ping failures gracefully and continues' do
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: false)])

      # Should not raise an error
      expect { connector.send(:ensure_lotus_available) }.not_to raise_error
    end

    it 'handles ping exceptions gracefully' do
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_raise(StandardError, 'Connection failed')

      # Should not raise an error
      expect { connector.send(:ensure_lotus_available) }.not_to raise_error
    end
  end

  describe '.reset_ping_cache' do
    it 'clears the pinged combinations cache' do
      # Ping once to populate cache
      allow(Open3).to receive(:capture3).and_return([nil, nil, double('status', success?: true)])
      connector.send(:ensure_lotus_available)

      # Reset cache
      described_class.reset_ping_cache

      # Should ping again after reset
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      connector.send(:ensure_lotus_available)
    end
  end
end