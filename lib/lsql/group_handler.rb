# frozen_string_literal: true

require 'yaml'
require 'pathname'

module Lsql
  # Handles group-based operations across multiple environments
  class GroupHandler
    CONFIG_FILE_NAME = '.lsql_groups.yml'
    
    def initialize(options)
      @options = options
      @config_path = find_config_file
    end

    def execute_for_group
      return false unless @options.group

      # Special case: list groups
      if @options.group == 'list'
        list_groups
        return true
      end

      # Prevent interactive sessions with groups
      if @options.sql_command.nil?
        puts "Error: Interactive sessions are not supported with group operations."
        puts "Please provide an SQL command or file to execute against the group."
        exit 1
      end

      config = load_config
      environments = get_group_environments(config, @options.group)
      
      if environments.empty?
        puts "Error: Group '#{@options.group}' not found or has no environments."
        puts "Available groups:"
        list_available_groups(config)
        exit 1
      end

      puts "Executing command for group '#{@options.group}' with environments: #{environments.join(', ')}"
      puts "=" * 60

      results = []
      environments.each_with_index do |env, index|
        puts "\n[#{index + 1}/#{environments.length}] Processing environment: #{env}"
        puts "-" * 40
        
        # Create a copy of options with the current environment
        env_options = @options.dup
        env_options.env = env
        
        begin
          result = execute_for_environment(env_options)
          results << { env: env, success: result }
          puts "✓ Completed environment: #{env}"
        rescue => e
          puts "✗ Failed environment: #{env} - #{e.message}"
          results << { env: env, success: false, error: e.message }
        end
      end

      print_summary(results)
      true
    end

    def list_groups
      config = load_config
      groups = config['groups'] || {}
      
      if groups.empty?
        puts "No groups found in configuration file: #{@config_path}"
        return
      end

      puts "Available groups in #{@config_path}:"
      puts "=" * 50
      groups.each do |name, group_config|
        description = group_config['description'] || 'No description'
        environments = group_config['environments'] || []
        puts "#{name}:"
        puts "  Description: #{description}"
        puts "  Environments (#{environments.length}): #{environments.join(', ')}"
        puts ""
      end
    end

    private

    def find_config_file
      # Look for config file starting from current directory and going up
      current_dir = Pathname.new(Dir.pwd)
      
      loop do
        config_path = current_dir + CONFIG_FILE_NAME
        return config_path.to_s if config_path.exist?
        
        parent = current_dir.parent
        break if parent == current_dir # reached root
        current_dir = parent
      end

      # If not found, use current directory
      File.join(Dir.pwd, CONFIG_FILE_NAME)
    end

    def load_config
      unless File.exist?(@config_path)
        create_sample_config
        puts "Error: Group configuration file not found."
        puts "A sample configuration has been created at: #{@config_path}"
        puts "Please edit it to define your environment groups."
        exit 1
      end

      begin
        YAML.load_file(@config_path)
      rescue => e
        puts "Error loading configuration file #{@config_path}: #{e.message}"
        exit 1
      end
    end

    def create_sample_config
      sample_config = {
        'groups' => {
          'staging' => {
            'description' => 'Staging environments',
            'environments' => ['staging', 'staging-s2', 'staging-s3', 'staging-s101', 'staging-s201']
          },
          'all-prod' => {
            'description' => 'All production environments',
            'environments' => ['prod', 'prod-s2', 'prod-s3', 'prod-s4', 'prod-s5', 'prod-s6', 'prod-s7', 'prod-s8', 'prod-s9', 'prod-s101', 'prod-s201']
          },
          'us-prod' => {
            'description' => 'All US production environments',
            'environments' => ['prod', 'prod-s2', 'prod-s3', 'prod-s4', 'prod-s5', 'prod-s6', 'prod-s7', 'prod-s8', 'prod-s9']
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
            'environments' => ['staging', 'staging-s2', 'staging-s3']
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
      }

      File.write(@config_path, sample_config.to_yaml)
    end

    def get_group_environments(config, group_name)
      return [] unless config&.dig('groups', group_name)
      
      group_config = config['groups'][group_name]
      group_config['environments'] || []
    end

    def execute_for_environment(env_options)
      # Setup environment
      EnvironmentManager.new(env_options)

      # Setup output file if needed (modify filename to include environment)
      output_manager = if env_options.output_file
                        # Create environment-specific output file
                        original_output = env_options.output_file
                        if original_output == 'PLACEHOLDER'
                          env_options.output_file = "#{env_options.env}_output"
                        else
                          # Insert environment name before file extension
                          ext = File.extname(original_output)
                          base = File.basename(original_output, ext)
                          dir = File.dirname(original_output)
                          env_options.output_file = File.join(dir, "#{base}_#{env_options.env}#{ext}")
                        end
                        OutputFileManager.new(env_options)
                      else
                        OutputFileManager.new(env_options)
                      end

      # Setup database connection
      db_connector = DatabaseConnector.new(env_options)
      database_url = db_connector.get_database_url

      # Execute SQL
      executor = SqlExecutor.new(env_options, output_manager, db_connector)
      executor.execute(database_url)
      
      true
    rescue => e
      puts "Error executing for environment #{env_options.env}: #{e.message}"
      false
    end

    def print_summary(results)
      puts "\n" + "=" * 60
      puts "EXECUTION SUMMARY"
      puts "=" * 60
      
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }
      
      puts "✓ Successful: #{successful.length}"
      successful.each { |r| puts "  - #{r[:env]}" }
      
      if failed.any?
        puts "\n✗ Failed: #{failed.length}"
        failed.each { |r| puts "  - #{r[:env]}: #{r[:error] || 'Unknown error'}" }
      end
      
      puts "\nTotal environments processed: #{results.length}"
    end

    def list_available_groups(config)
      groups = config['groups'] || {}
      groups.each do |name, group_config|
        environments = group_config['environments'] || []
        puts "  - #{name} (#{environments.length} environments)"
      end
    end
  end
end
