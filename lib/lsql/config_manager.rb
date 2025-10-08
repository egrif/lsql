# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module LSQL
  class ConfigManager
    CONFIG_DIR = File.expand_path('~/.lsql')
    CONFIG_FILE = File.join(CONFIG_DIR, 'settings.yml')
    DEFAULT_CONFIG_FILE = File.join(File.dirname(__FILE__), '..', '..', 'config', 'settings.yml')

    DEFAULT_CONFIG = {
      'cache' => {
        'prefix' => 'db_url',
        'ttl_minutes' => 10,
        'directory' => File.join(CONFIG_DIR, 'cache')
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
      # Load default configuration first
      default_config = load_default_config

      # Load user configuration if it exists
      user_config = if File.exist?(CONFIG_FILE)
                      begin
                        YAML.load_file(CONFIG_FILE) || {}
                      rescue StandardError => e
                        puts "Warning: Failed to load config file #{CONFIG_FILE}: #{e.message}"
                        {}
                      end
                    else
                      {}
                    end

      # Merge configurations with user settings taking precedence
      deep_merge(default_config, user_config)
    end

    def self.load_default_config
      if File.exist?(DEFAULT_CONFIG_FILE)
        begin
          config = YAML.load_file(DEFAULT_CONFIG_FILE) || {}
          # Expand cache directory path relative to user's home
          config['cache']['directory'] = File.expand_path(config['cache']['directory']) if config.dig('cache', 'directory')
          config
        rescue StandardError => e
          puts "Warning: Failed to load default config file #{DEFAULT_CONFIG_FILE}: #{e.message}"
          DEFAULT_CONFIG
        end
      else
        # Fallback to hardcoded defaults if default config file doesn't exist
        DEFAULT_CONFIG
      end
    end

    def self.deep_merge(default_hash, override_hash)
      default_hash.merge(override_hash) do |_key, default_val, override_val|
        if default_val.is_a?(Hash) && override_val.is_a?(Hash)
          deep_merge(default_val, override_val)
        else
          override_val
        end
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

    def self.get_cache_directory(explicit_value = nil, env_value = nil)
      # Priority: 1. Explicit parameter, 2. Environment variable, 3. Config file, 4. Default
      return File.expand_path(explicit_value) if explicit_value
      return File.expand_path(env_value) if env_value

      config = load_config
      cache_dir = config.dig('cache', 'directory') || DEFAULT_CONFIG['cache']['directory']
      File.expand_path(cache_dir)
    end

    def self.migrate_legacy_cache
      old_cache_dir = File.expand_path('~/.lsql_cache')
      new_cache_dir = get_cache_directory

      return unless Dir.exist?(old_cache_dir) && old_cache_dir != new_cache_dir

      puts "Migrating cache from #{old_cache_dir} to #{new_cache_dir}..."

      # Ensure new cache directory exists
      FileUtils.mkdir_p(new_cache_dir)

      # Move all files from old to new location
      Dir.glob(File.join(old_cache_dir, '*')).each do |file|
        next unless File.file?(file)

        filename = File.basename(file)
        new_file_path = File.join(new_cache_dir, filename)

        # Only move if file doesn't already exist in new location
        unless File.exist?(new_file_path)
          FileUtils.mv(file, new_file_path)
          puts "  Moved #{filename}" if ENV['LSQL_VERBOSE']
        end
      end

      # Remove old cache directory if empty
      begin
        Dir.rmdir(old_cache_dir) if Dir.empty?(old_cache_dir)
        puts 'Migration completed successfully.'
      rescue Errno::ENOTEMPTY
        puts 'Migration completed. Old cache directory retained (contains additional files).'
      rescue StandardError => e
        puts "Migration completed with warnings: #{e.message}"
      end
    end

    def self.create_default_config
      return if File.exist?(CONFIG_FILE)

      FileUtils.mkdir_p(CONFIG_DIR)

      config_content = <<~YAML
        # LSQL User Configuration File
        # This file overrides the default settings in config/settings.yml
        # Only include settings you want to customize

        # Uncomment and customize cache settings as needed:
        # cache:
        #   prefix: myteam_db_urls
        #   ttl_minutes: 30
        #   directory: ~/.lsql/cache

        # Uncomment and add custom environment groups:
        # groups:
        #   my-custom-group:
        #     description: My custom environments
        #     environments:
        #       - env1
        #       - env2

        # Uncomment and customize prompt settings:
        # prompts:
        #   colors:
        #     production: "\\033[0;31m"     # Red for production
        #     development: "\\033[0;33m"    # Yellow for development
        #   production_patterns:
        #     - "^prod"
        #     - "^live"
        #   templates:
        #     colored: "{color}{env}{mode}:%/%R%\\#\\{reset\\} "
        #     plain: "{space}:{mode_short} > {env}{mode}:%/%R%# "
      YAML

      File.write(CONFIG_FILE, config_content)
      puts "Created user config file: #{CONFIG_FILE}"
      puts 'Default settings are loaded from the built-in configuration.'
      puts 'Edit this file to customize cache settings and add custom groups.'
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

    def self.get_prompt_config
      config = load_config
      config['prompts'] || DEFAULT_CONFIG['prompts']
    end

    def self.get_prompt_colors
      prompt_config = get_prompt_config
      prompt_config['colors'] || {}
    end

    def self.get_production_patterns
      prompt_config = get_prompt_config
      prompt_config['production_patterns'] || []
    end

    def self.get_prompt_templates
      prompt_config = get_prompt_config
      prompt_config['templates'] || {}
    end

    def self.is_production_environment?(env_name)
      patterns = get_production_patterns
      patterns.any? { |pattern| env_name =~ Regexp.new(pattern, Regexp::IGNORECASE) }
    end
  end
end
