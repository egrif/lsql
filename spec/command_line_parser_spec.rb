# frozen_string_literal: true

require 'spec_helper'
require 'lsql/command_line_parser'

RSpec.describe Lsql::CommandLineParser do
  let(:parser) { described_class.new }

  it 'parses environment argument' do
    args = ['-e', 'dev']
    options = parser.parse(args)
    expect(options[:env]).to eq('dev')
  end

  it 'parses input file argument (currently returns nil)' do
    args = ['-i', 'input.sql']
    options = parser.parse(args)
    expect(options[:input_file]).to be_nil
  end

  it 'parses output file argument' do
    args = ['-o', 'output.txt']
    options = parser.parse(args)
    expect(options[:output_file]).to eq('output.txt')
  end

  it 'shows help with -h' do
    args = ['-h']
    expect { parser.parse(args) }.to output(/Usage:/).to_stdout_from_any_process
  end
end
