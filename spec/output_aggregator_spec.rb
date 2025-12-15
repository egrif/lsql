# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
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

  it 'extracts columns from environments with no rows (SELECT * scenario)' do
    # Simulate scenario where most environments have no rows but one has data
    # This tests the fix for SELECT * queries where columns need to be extracted from headers
    env1 = 'prod-s2'
    env2 = 'prod-s3'
    env3 = 'prod-s9'

    # Environment with no rows - still has header and separator
    no_rows_output = "oid | extname | extowner | extnamespace | extrelocatable | extversion | extconfig | extcondition\n" \
                     "----+---------+----------+--------------+----------------+------------+-----------+--------------\n" \
                     "(0 rows)\n"

    # Environment with one row
    one_row_output = "oid | extname | extowner | extnamespace | extrelocatable | extversion | extconfig | extcondition\n" \
                     "----+---------+----------+--------------+----------------+------------+-----------+--------------\n " \
                     "123 | pg_repack | 10 | 2200 | t | 1.4.8 | |\n" \
                     "(1 row)\n"

    path1 = aggregator.create_temp_file(env1)
    path2 = aggregator.create_temp_file(env2)
    path3 = aggregator.create_temp_file(env3)

    File.write(path1, no_rows_output)
    File.write(path2, no_rows_output)
    File.write(path3, one_row_output)

    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    aggregator.aggregate_output(nil)
    $stdout = original_stdout
    output_string = output.string

    # Verify columns are extracted from environments with no rows
    expect(output_string).to include('extname')
    expect(output_string).to include('extversion')
    expect(output_string).to include('extowner')
    # Verify data row from environment with data is included
    expect(output_string).to include('prod-s9')
    expect(output_string).to include('pg_repack')
    expect(output_string).to include('1.4.8')
  end

  it 'displays status messages for environments with no tabular data' do
    env1 = 'update_env'
    env2 = 'empty_env'

    update_output = "UPDATE 3\n"
    empty_output = "No relations found.\n"

    path1 = aggregator.create_temp_file(env1)
    path2 = aggregator.create_temp_file(env2)

    File.write(path1, update_output)
    File.write(path2, empty_output)

    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    aggregator.aggregate_output(nil)
    $stdout = original_stdout
    output_string = output.string

    expect(output_string).to include('update_env')
    expect(output_string).to include('UPDATE 3')
    expect(output_string).to include('empty_env')
    expect(output_string).to include('(no data returned)')
  end
end
