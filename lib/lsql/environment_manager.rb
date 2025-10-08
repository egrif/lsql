# frozen_string_literal: true

require_relative 'command_line_parser'

module Lsql
  # Handles environment and region determination for single or multiple environments
  class EnvironmentManager
    attr_reader :environments

    def initialize(options)
      @options = options
      @environments = parse_environments
    end

    def multiple_environments?
      @environments.length > 1
    end

    def single_environment?
      @environments.length == 1
    end

    def primary_environment
      @environments.first
    end

    private

    def parse_environments
      if CommandLineParser.multiple_environments?(@options.env)
        # Parse multiple environments with à la carte specifications
        env_specs = CommandLineParser.parse_environments(
          @options.env,
          @options.space,
          @options.region
        )

        # Create environment options for each specification
        env_specs.map do |spec|
          create_environment_options(spec)
        end
      else
        # Single environment - use existing logic
        determine_space_and_region
        [@options]
      end
    end

    def create_environment_options(env_spec)
      # Create a copy of the original options with environment-specific overrides
      env_options = @options.dup
      env_options.env = env_spec[:env]

      # Apply space and region with proper precedence:
      # 1. Per-environment specification (ENV:SPACE:REGION)
      # 2. CLI flags (-s/-r)
      # 3. Environment-based defaults
      # 4. Global defaults

      if env_spec[:space]
        env_options.space = env_spec[:space]
      elsif @options.space.nil?
        # Apply default logic based on environment name
        env_options.space = (env_spec[:env] =~ /^(prod|staging)/i ? 'prod' : 'dev')
      end

      if env_spec[:region]
        env_options.region = env_spec[:region]
      elsif @options.region.nil?
        # Apply default logic based on environment name
        env_options.region = case env_spec[:env]
                             when /2[0-9][1-9]$/
                               'apse2'
                             when /1[0-9][1-9]$/
                               'euc1'
                             when /[0-9][0-9]?$/
                               'use1'
                             else
                               'use1' # Default region
                             end
      end

      env_options
    end

    def determine_space_and_region
      # Set the default space based on the environment
      @options.space ||= (@options.env =~ /^(prod|staging)/i ? 'prod' : 'dev')

      # Set the REGION based on the ending digits of ENV if not already specified
      if @options.region.nil?
        case @options.env
        when /2[0-9][1-9]$/
          @options.region = 'apse2'
        when /1[0-9][1-9]$/
          @options.region = 'euc1'
        when /[0-9][0-9]?$/
          @options.region = 'use1'
        end
      end

      @options.region ||= 'use1' # Default region
    end
  end
end
