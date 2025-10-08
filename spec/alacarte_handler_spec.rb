# frozen_string_literal: true

require 'ostruct'
require_relative '../lib/lsql/command_line_parser'
require_relative '../lib/lsql/environment_manager'

# Test the new à la carte environment parsing
describe 'CommandLineParser' do
  describe '.parse_environments' do
    it 'parses single environment without space or region' do
      result = Lsql::CommandLineParser.parse_environments('prod01')
      expect(result).to eq([
                             { env: 'prod01', space: nil, region: nil }
                           ])
    end

    it 'parses single environment with space and region' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod:use1')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'use1' }
                           ])
    end

    it 'parses multiple environments with mixed specifications' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod:use1,dev02:dev:euc1,staging03')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'use1' },
                             { env: 'dev02', space: 'dev', region: 'euc1' },
                             { env: 'staging03', space: nil, region: nil }
                           ])
    end

    it 'applies fallback values when space/region are omitted' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod,dev02::euc1,staging03', 'default_space', 'default_region')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'default_region' },
                             { env: 'dev02', space: 'default_space', region: 'euc1' },
                             { env: 'staging03', space: 'default_space', region: 'default_region' }
                           ])
    end
  end

  describe '.multiple_environments?' do
    it 'returns true for multiple environments' do
      expect(Lsql::CommandLineParser.multiple_environments?('prod01,dev02')).to be true
      expect(Lsql::CommandLineParser.multiple_environments?('prod01:prod:use1,dev02:dev:euc1')).to be true
    end

    it 'returns false for single environment' do
      expect(Lsql::CommandLineParser.multiple_environments?('prod01')).to be false
      expect(Lsql::CommandLineParser.multiple_environments?('prod01:prod:use1')).to be false
    end

    it 'returns false for nil or empty string' do
      expect(Lsql::CommandLineParser.multiple_environments?(nil)).to be false
      expect(Lsql::CommandLineParser.multiple_environments?('')).to be false
    end
  end
end

describe 'EnvironmentManager' do
  let(:options) { OpenStruct.new(env: nil, space: nil, region: nil, sql_command: 'SELECT 1') }

  describe 'single environment' do
    before { options.env = 'prod01' }

    it 'handles single environment correctly' do
      env_manager = Lsql::EnvironmentManager.new(options)
      expect(env_manager.single_environment?).to be true
      expect(env_manager.multiple_environments?).to be false
      expect(env_manager.environments.length).to eq(1)
      expect(env_manager.primary_environment.env).to eq('prod01')
    end
  end

  describe 'multiple environments' do
    before { options.env = 'prod01:prod:use1,dev02:dev:euc1' }

    it 'handles multiple environments correctly' do
      env_manager = Lsql::EnvironmentManager.new(options)
      expect(env_manager.multiple_environments?).to be true
      expect(env_manager.single_environment?).to be false
      expect(env_manager.environments.length).to eq(2)

      first_env = env_manager.environments[0]
      expect(first_env.env).to eq('prod01')
      expect(first_env.space).to eq('prod')
      expect(first_env.region).to eq('use1')

      second_env = env_manager.environments[1]
      expect(second_env.env).to eq('dev02')
      expect(second_env.space).to eq('dev')
      expect(second_env.region).to eq('euc1')
    end
  end

  describe 'environment defaults' do
    context 'with production environment' do
      before { options.env = 'prod99' }

      it 'applies production defaults' do
        env_manager = Lsql::EnvironmentManager.new(options)
        env = env_manager.primary_environment
        expect(env.space).to eq('prod')
        expect(env.region).to eq('use1') # Default for XX environments
      end
    end

    context 'with regional environment' do
      before { options.env = 'staging-s101' }

      it 'applies regional defaults' do
        env_manager = Lsql::EnvironmentManager.new(options)
        env = env_manager.primary_environment
        expect(env.space).to eq('prod') # staging matches /^(prod|staging)/i
        expect(env.region).to eq('euc1') # 1XX environments
      end
    end
  end
end
