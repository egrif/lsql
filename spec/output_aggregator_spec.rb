require 'spec_helper'
require 'lsql/output_aggregator'

RSpec.describe Lsql::OutputAggregator do
  let(:options) { {} }
  let(:aggregator) { described_class.new(options) }

  it 'outputs environment-prefixed lines to stdout including header' do
    envs = %w[dev prod]
    lines = ["id | name | value\n", "1 | foo | 42\n", "2 | bar | 99\n"]
    envs.each do |env|
      path = aggregator.create_temp_file(env)
      File.write(path, lines.join)
    end
    expect { aggregator.aggregate_output(nil) }.to output(/env\s+\| id \| name \| value/).to_stdout
    expect { aggregator.aggregate_output(nil) }.to output(/dev\s+\| 1 \| foo \| 42/).to_stdout
    expect { aggregator.aggregate_output(nil) }.to output(/prod\s+\| 1 \| foo \| 42/).to_stdout
  end

  it 'writes output to a file if specified including header' do
    env = 'test'
    lines = ["id | name\n", "1 | foo\n"]
    path = aggregator.create_temp_file(env)
    File.write(path, lines.join)
    output_file = 'tmp_output.txt'
    aggregator.aggregate_output(output_file)
    content = File.read(output_file)
    expect(content).to include('env  | id | name')
    expect(content).to include('test | 1 | foo')
    File.delete(output_file)
  end
end
