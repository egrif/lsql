# frozen_string_literal: true

require 'spec_helper'
require 'lsql/output_file_manager'

RSpec.describe Lsql::OutputFileManager do
  let(:options) { Struct.new(:output_file, :env).new(nil, 'test') }
  let(:manager) { described_class.new(options) }

  it 'initializes without output file' do
    expect(manager).to be_an(Lsql::OutputFileManager)
    expect(options.output_file).to be_nil
  end

  it 'generates placeholder output file when needed' do
    options.output_file = 'PLACEHOLDER'
    manager.setup_output_file
    expect(options.output_file).to include('test') # env name
    expect(options.output_file).to match(/\d{8}_test_\d{4}/) # date_env_serial format
  end

  it 'detects temp files correctly' do
    options.output_file = '/tmp/lsql_temp_12345.txt'
    expect(manager.temp_file?).to be true

    options.output_file = '/home/user/regular_file.txt'
    expect(manager.temp_file?).to be false
  end

  it 'provides psql options for CSV files' do
    options.output_file = 'output.csv'
    expect(manager.get_psql_options).to include('-t -A -F","')

    options.output_file = 'output.txt'
    expect(manager.get_psql_options).to eq('')
  end

  describe 'format option handling' do
    let(:options_with_format) { Struct.new(:output_file, :env, :format).new(nil, 'test', nil) }
    let(:manager_with_format) { described_class.new(options_with_format) }

    it 'provides psql options for CSV format' do
      options_with_format.format = 'csv'
      expect(manager_with_format.get_psql_options).to include('-t -A -F","')
    end

    it 'provides psql options for JSON format' do
      options_with_format.format = 'json'
      expect(manager_with_format.get_psql_options).to include('-t -A')
    end

    it 'provides psql options for YAML format' do
      options_with_format.format = 'yaml'
      expect(manager_with_format.get_psql_options).to include('-t -A')
    end

    it 'provides psql options for TXT format' do
      options_with_format.format = 'txt'
      expect(manager_with_format.get_psql_options).to include('-t -A')
    end

    it 'detects format from file extension when format option not specified' do
      options_with_format.output_file = 'output.json'
      expect(manager_with_format.get_psql_options).to include('-t -A')

      options_with_format.output_file = 'output.yaml'
      expect(manager_with_format.get_psql_options).to include('-t -A')

      options_with_format.output_file = 'output.yml'
      expect(manager_with_format.get_psql_options).to include('-t -A')
    end

    it 'format option overrides file extension detection' do
      options_with_format.output_file = 'output.txt'
      options_with_format.format = 'csv'
      expect(manager_with_format.get_psql_options).to include('-t -A -F","')
    end

    it 'returns empty options when no format and no output file' do
      expect(manager_with_format.get_psql_options).to eq('')
    end
  end
end
