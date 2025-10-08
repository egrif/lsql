# frozen_string_literal: true

require 'spec_helper'
require 'lsql/output_aggregator'

RSpec.describe Lsql::OutputAggregator do
  let(:options) { {} }
  let(:aggregator) { described_class.new(options) }

  it 'outputs environment-prefixed lines to stdout with content header' do
    env = 'dev'
    postgresql_output = "id | name | value\n---+------+-------\n 1 | foo  | 42\n(1 row)\n"
    path = aggregator.create_temp_file(env)
    File.write(path, postgresql_output)

    expect { aggregator.aggregate_output(nil) }.to output(/env\s+\| id\s+\| name\s+\| value/).to_stdout
  end

  it 'writes output to a file if specified with content header' do
    env = 'test'
    postgresql_output = "id | name\n---+------\n 1 | foo\n(1 row)\n"
    path = aggregator.create_temp_file(env)
    File.write(path, postgresql_output)
    output_file = 'tmp_output.txt'
    aggregator.aggregate_output(output_file)
    content = File.read(output_file)
    # Verify header contains correct column names (spacing may vary based on content)
    expect(content).to include('env')
    expect(content).to include('id')
    expect(content).to include('name')
    # Verify data row content is present
    expect(content).to include('test')
    expect(content).to include('1')
    expect(content).to include('foo')
    File.delete(output_file)
  end
end
