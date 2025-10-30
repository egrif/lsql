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
                             { env: 'prod01', space: nil, region: nil, cluster: nil }
                           ])
    end

    it 'parses single environment with space and region' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod:use1')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'use1', cluster: nil }
                           ])
    end

    it 'parses multiple environments with mixed specifications' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod:use1,dev02:dev:euc1,staging03')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'use1', cluster: nil },
                             { env: 'dev02', space: 'dev', region: 'euc1', cluster: nil },
                             { env: 'staging03', space: nil, region: nil, cluster: nil }
                           ])
    end

    it 'applies fallback values when space/region are omitted' do
      result = Lsql::CommandLineParser.parse_environments('prod01:prod,dev02::euc1,staging03', 'default_space', 'default_region')
      expect(result).to eq([
                             { env: 'prod01', space: 'prod', region: 'default_region', cluster: nil },
                             { env: 'dev02', space: 'default_space', region: 'euc1', cluster: nil },
                             { env: 'staging03', space: 'default_space', region: 'default_region', cluster: nil }
                           ])
    end

    it 'extracts cluster from environment names with dashes' do
      result = Lsql::CommandLineParser.parse_environments('prod-use1-0,dev-euc1-1,staging-apse2-2')
      expect(result).to eq([
                             { env: 'prod-use1-0', space: nil, region: nil, cluster: 'prod-use1-0' },
                             { env: 'dev-euc1-1', space: nil, region: nil, cluster: 'dev-euc1-1' },
                             { env: 'staging-apse2-2', space: nil, region: nil, cluster: 'staging-apse2-2' }
                           ])
    end

    it 'applies fallback cluster when environment has no dashes' do
      result = Lsql::CommandLineParser.parse_environments('prod01,dev02', nil, nil, 'default-cluster')
      expect(result).to eq([
                             { env: 'prod01', space: nil, region: nil, cluster: 'default-cluster' },
                             { env: 'dev02', space: nil, region: nil, cluster: 'default-cluster' }
                           ])
    end

    it 'prioritizes extracted cluster over fallback cluster' do
      result = Lsql::CommandLineParser.parse_environments('prod-use1-0,dev02', nil, nil, 'default-cluster')
      expect(result).to eq([
                             { env: 'prod-use1-0', space: nil, region: nil, cluster: 'prod-use1-0' },
                             { env: 'dev02', space: nil, region: nil, cluster: 'default-cluster' }
                           ])
    end
  end

  describe '.extract_cluster_from_env' do
    it 'extracts cluster from environment names with dashes' do
      expect(Lsql::CommandLineParser.extract_cluster_from_env('prod-use1-0')).to eq('prod-use1-0')
      expect(Lsql::CommandLineParser.extract_cluster_from_env('dev-euc1-1')).to eq('dev-euc1-1')
      expect(Lsql::CommandLineParser.extract_cluster_from_env('staging-apse2-2')).to eq('staging-apse2-2')
    end

    it 'returns nil for environment names without dashes' do
      expect(Lsql::CommandLineParser.extract_cluster_from_env('prod01')).to be_nil
      expect(Lsql::CommandLineParser.extract_cluster_from_env('dev02')).to be_nil
      expect(Lsql::CommandLineParser.extract_cluster_from_env('staging03')).to be_nil
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
  let(:options) do
    Struct.new(:env, :space, :region, :cluster, :sql_command, keyword_init: true)
          .new(env: nil, space: nil, region: nil, cluster: nil, sql_command: 'SELECT 1')
  end

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

    context 'with cluster environment' do
      before { options.env = 'prod-use1-0' }

      it 'extracts cluster from environment name' do
        env_manager = Lsql::EnvironmentManager.new(options)
        env = env_manager.primary_environment
        expect(env.cluster).to eq('prod-use1-0')
      end
    end

    context 'with cluster from CLI' do
      before do
        options.env = 'prod01'
        options.cluster = 'custom-cluster'
      end

      it 'uses CLI cluster when environment has no dashes' do
        env_manager = Lsql::EnvironmentManager.new(options)
        env = env_manager.primary_environment
        expect(env.cluster).to eq('custom-cluster')
      end
    end

    context 'with both extracted and CLI cluster' do
      before do
        options.env = 'prod-use1-0'
        options.cluster = 'custom-cluster'
      end

      it 'prioritizes extracted cluster over CLI cluster' do
        env_manager = Lsql::EnvironmentManager.new(options)
        env = env_manager.primary_environment
        expect(env.cluster).to eq('prod-use1-0')
      end
    end
  end
end
