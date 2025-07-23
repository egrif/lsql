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

      # Initialize output aggregator if aggregation is enabled
      # Use aggregation unless --no-agg flag is specified
      aggregator = @options.no_agg ? nil : OutputAggregator.new(@options)
      original_output_file = @options.output_file

      # Initialize progress tracking for non-verbose mode (only for aggregated output)
      spinner_chars = ['|', '/', '-', '\\']
      spinner_index = 0
      if !@options.verbose && !@options.no_agg
        print "Progress: "
        $stdout.flush
      end

      results = []
      environments.each_with_index do |env, index|
        if @options.verbose
          puts "\n[#{index + 1}/#{environments.length}] Processing environment: #{env}"
          puts "-" * 40
        elsif !@options.no_agg
          # Show dot at the beginning of each query and start spinner
          print "."
          $stdout.flush
        end
        
        # Create a copy of options with the current environment
        env_options = @options.dup
        env_options.env = env
        
        # Start spinner for non-verbose aggregated mode
        spinner_thread = nil
        if !@options.verbose && !@options.no_agg
          spinner_thread = Thread.new do
            begin
              loop do
                print "\b#{spinner_chars[spinner_index % 4]}"
                $stdout.flush
                spinner_index += 1
                sleep(0.2)
              end
            rescue ThreadError
              # Thread was killed, exit cleanly
            end
          end
        end
        
        begin
          result = execute_for_environment(env_options, aggregator)
          results << { env: env, success: result }
          
          # Stop spinner and show completion
          if !@options.verbose && !@options.no_agg && spinner_thread
            spinner_thread.kill
            spinner_thread.join(0.1)
            print "\b "
            $stdout.flush
          elsif @options.verbose
            puts "✓ Completed environment: #{env}"
          end
        rescue => e
          # Stop spinner on error
          if !@options.verbose && !@options.no_agg && spinner_thread
            spinner_thread.kill
            spinner_thread.join(0.1)
            print "\b✗"
            $stdout.flush
          elsif @options.verbose
            puts "✗ Failed environment: #{env} - #{e.message}"
          end
          results << { env: env, success: false, error: e.message }
        end
      end

      # Complete the progress line for non-verbose mode (only for aggregated output)
      if !@options.verbose && !@options.no_agg
        puts " done"
      end

      # If using aggregation, output the aggregated results
      if aggregator
        puts "\n" + "=" * 60
        puts "AGGREGATED OUTPUT"
        puts "=" * 60
        aggregator.aggregate_output(original_output_file)
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

    def execute_for_environment(env_options, aggregator = nil)
      # Setup environment
      EnvironmentManager.new(env_options)

      # Setup output file if needed (modify filename to include environment or use aggregator)
      output_manager = if aggregator
                        # For aggregation, use a temporary file
                        temp_file = aggregator.get_temp_file_for_env(env_options.env)
                        env_options.output_file = temp_file
                        OutputFileManager.new(env_options)
                      elsif env_options.output_file
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
      if @options.verbose
        puts "Error executing for environment #{env_options.env}: #{e.message}"
      end
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
