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
    expect(content).to include('env  | id  | name')
    expect(content).to include('test | 1   | foo')
    File.delete(output_file)
  end
end
