# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module LSQL
  class ConfigManager
    CONFIG_DIR = File.expand_path('~/.lsql')
    CONFIG_FILE = File.join(CONFIG_DIR, 'config.yml')

    DEFAULT_CONFIG = {
      'cache' => {
        'prefix' => 'db_url',
        'ttl_minutes' => 10
      },
      'groups' => {
        'staging' => {
          'description' => 'Staging environments',
          'environments' => %w[staging staging-s2 staging-s3 staging-s101 staging-s201]
        },
        'all-prod' => {
          'description' => 'All production environments',
          'environments' => %w[prod prod-s2 prod-s3 prod-s4 prod-s5 prod-s6 prod-s7 prod-s8
                               prod-s9 prod-s101 prod-s201]
        },
        'us-prod' => {
          'description' => 'All US production environments',
          'environments' => %w[prod prod-s2 prod-s3 prod-s4 prod-s5 prod-s6 prod-s7 prod-s8
                               prod-s9]
        },
        'eu-prod' => {
          'description' => 'All EU production environments',
          'environments' => ['prod-s101']
        },
        'apse-prod' => {
          'description' => 'All AP Southeast production environments',
          'environments' => ['prod-s201']
        },
        'us-staging' => {
          'description' => 'All US staging environments',
          'environments' => %w[staging staging-s2 staging-s3]
        },
        'eu-staging' => {
          'description' => 'All EU staging environments',
          'environments' => ['staging-s101']
        },
        'apse-staging' => {
          'description' => 'All AP Southeast staging environments',
          'environments' => ['staging-s201']
        }
      }
    }.freeze

    def self.load_config
      if File.exist?(CONFIG_FILE)
        begin
          YAML.load_file(CONFIG_FILE) || {}
        rescue StandardError => e
          puts "Warning: Failed to load config file #{CONFIG_FILE}: #{e.message}"
          {}
        end
      else
        {}
      end
    end

    def self.get_cache_prefix(explicit_value = nil, env_value = nil)
      # Priority: 1. Explicit parameter, 2. Environment variable, 3. Config file, 4. Default
      return explicit_value if explicit_value
      return env_value if env_value

      config = load_config
      config.dig('cache', 'prefix') || DEFAULT_CONFIG['cache']['prefix']
    end

    def self.get_cache_ttl(explicit_value = nil, env_value = nil)
      # Priority: 1. Explicit parameter, 2. Environment variable, 3. Config file, 4. Default
      return explicit_value if explicit_value
      return env_value if env_value

      config = load_config
      ttl_minutes = config.dig('cache', 'ttl_minutes') || DEFAULT_CONFIG['cache']['ttl_minutes']
      ttl_minutes * 60 # Convert to seconds
    end

    def self.create_default_config
      return if File.exist?(CONFIG_FILE)

      FileUtils.mkdir_p(CONFIG_DIR)

      config_content = <<~YAML
        # LSQL Configuration File
        # This file contains settings and group definitions for the LSQL command-line tool

        cache:
          # Cache key prefix (default: db_url)
          # Cache keys use format: lsql:{prefix}:{space}_{env}_{region}_{app}
          prefix: db_url
        #{'  '}
          # Cache TTL in minutes (default: 10)
          # How long database URLs are cached before requiring fresh lookup
          ttl_minutes: 10

        # Environment groups for batch operations
        groups:
          staging:
            description: Staging environments
            environments:
              - staging
              - staging-s2
              - staging-s3
              - staging-s101
              - staging-s201
        #{'  '}
          all-prod:
            description: All production environments
            environments:
              - prod
              - prod-s2
              - prod-s3
              - prod-s4
              - prod-s5
              - prod-s6
              - prod-s7
              - prod-s8
              - prod-s9
              - prod-s101
              - prod-s201
        #{'  '}
          us-prod:
            description: All US production environments
            environments:
              - prod
              - prod-s2
              - prod-s3
              - prod-s4
              - prod-s5
              - prod-s6
              - prod-s7
              - prod-s8
              - prod-s9
        #{'  '}
          eu-prod:
            description: All EU production environments
            environments:
              - prod-s101
        #{'  '}
          apse-prod:
            description: All AP Southeast production environments
            environments:
              - prod-s201
        #{'  '}
          us-staging:
            description: All US staging environments
            environments:
              - staging
              - staging-s2
              - staging-s3
        #{'  '}
          eu-staging:
            description: All EU staging environments
            environments:
              - staging-s101
        #{'  '}
          apse-staging:
            description: All AP Southeast staging environments
            environments:
              - staging-s201

        # Example custom configuration:
        # cache:
        #   prefix: myteam_db_urls
        #   ttl_minutes: 30
        ##{' '}
        # groups:
        #   my-custom-group:
        #     description: My custom environments
        #     environments:
        #       - env1
        #       - env2
      YAML

      File.write(CONFIG_FILE, config_content)
      puts "Created default config file: #{CONFIG_FILE}"
    end

    def self.show_config(cli_prefix = nil, cli_ttl = nil)
      config = load_config
      env_prefix = ENV.fetch('LSQL_CACHE_PREFIX', nil)
      env_ttl = ENV.fetch('LSQL_CACHE_TTL', nil) && (ENV['LSQL_CACHE_TTL'].to_i * 60) # Convert to seconds

      effective_config = {
        'cache' => {
          'prefix' => get_cache_prefix(cli_prefix, env_prefix),
          'ttl_minutes' => (cli_ttl || get_cache_ttl(nil, env_ttl)) / 60
        }
      }

      puts "Configuration File: #{CONFIG_FILE}"
      puts "File exists: #{File.exist?(CONFIG_FILE)}"
      puts
      puts 'Effective Configuration:'
      puts YAML.dump(effective_config)

      # Show priority information
      puts 'Priority Information:'
      prefix_source = if cli_prefix
                        'CLI parameter'
                      elsif env_prefix
                        'environment variable'
                      elsif File.exist?(CONFIG_FILE) && config.dig('cache', 'prefix')
                        'config file'
                      else
                        'default'
                      end

      ttl_source = if cli_ttl
                     'CLI parameter'
                   elsif env_ttl
                     'environment variable'
                   elsif File.exist?(CONFIG_FILE) && config.dig('cache', 'ttl_minutes')
                     'config file'
                   else
                     'default'
                   end

      puts "  cache_prefix: #{prefix_source}"
      puts "  cache_ttl: #{ttl_source}"
      puts

      return unless File.exist?(CONFIG_FILE)

      puts 'Raw Config File Contents:'
      puts File.read(CONFIG_FILE)
    end

    def self.config_file_path
      CONFIG_FILE
    end

    def self.get_groups
      config = load_config
      config['groups'] || DEFAULT_CONFIG['groups']
    end

    def self.get_group_environments(group_name)
      groups = get_groups
      return [] unless groups&.dig(group_name)

      group_config = groups[group_name]
      group_config['environments'] || []
    end

    def self.group_exists?(group_name)
      groups = get_groups
      groups&.key?(group_name) || false
    end

    def self.list_available_groups
      groups = get_groups
      groups.each do |name, group_config|
        environments = group_config['environments'] || []
        puts "  - #{name} (#{environments.length} environments)"
      end
    end
  end
end
