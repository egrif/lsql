# frozen_string_literal: true

module Lsql
  # Handles environment and region determination
  class EnvironmentManager
    def initialize(options)
      @options = options
      determine_space_and_region
    end

    def determine_space_and_region
      # Set the default space based on the environment
      @options.space ||= (@options.env =~ /^(prod|staging)/i ? 'prod' : 'dev')

      # Set the REGION based on the ending digits of ENV if not already specified
      if @options.region.nil?
        case @options.env
        when /[2][0-9][1-9]$/
          @options.region = 'apse2'
        when /[1][0-9][1-9]$/
          @options.region = 'euc1'
        when /[0-9][0-9]?$/
          @options.region = 'use1'
        end
      end

      @options.region ||= 'use1' # Default region
    end
  end
end
