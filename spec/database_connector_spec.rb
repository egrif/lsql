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

  describe '.ping_space_region_combinations' do
    it 'pings lotus with the correct space and region parameters' do
      combinations = [['prod', 'use1']]
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: true)])

      described_class.ping_space_region_combinations(combinations)
    end

    it 'only pings once for the same space/region combination' do
      combinations = [['prod', 'use1'], ['prod', 'use1']]
      
      # Should only ping once even though combination is listed twice
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .once
        .and_return([nil, nil, double('status', success?: true)])

      described_class.ping_space_region_combinations(combinations)
    end

    it 'pings separately for different space/region combinations' do
      combinations = [['prod', 'use1'], ['dev', 'euc1']]

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
      combinations = [['prod', 'use1']]
      expect(Open3).to receive(:capture3)
        .with('lotus ping -s prod -r use1 > /dev/null 2>&1')
        .and_return([nil, nil, double('status', success?: false)])

      # Should not raise an error
      expect { described_class.ping_space_region_combinations(combinations) }.not_to raise_error
    end

    it 'handles ping exceptions gracefully' do
      combinations = [['prod', 'use1']]
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
      described_class.ping_space_region_combinations([['prod', 'use1']])
      
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
      described_class.ping_space_region_combinations([['prod', 'use1']])

      # Verify cache is populated
      expect(connector.send(:ensure_lotus_available)).to be true

      # Reset cache
      described_class.reset_ping_cache

      # Verify cache is cleared
      expect(connector.send(:ensure_lotus_available)).to be false
    end
  end
end
