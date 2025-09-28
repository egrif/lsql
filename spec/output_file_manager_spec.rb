require 'spec_helper'
require 'lsql/output_file_manager'

RSpec.describe Lsql::OutputFileManager do
  let(:options) { OpenStruct.new(output_file: nil, env: 'test') }
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
end
