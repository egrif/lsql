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
    args = ['-i', 'input.sql', '-e', 'test']
    options = parser.parse(args)
    expect(options[:input_file]).to be_nil
  end

  it 'parses output file argument' do
    args = ['-o', 'output.txt', '-e', 'test']
    options = parser.parse(args)
    expect(options[:output_file]).to eq('output.txt')
  end

  it 'shows help with -h' do
    args = ['-h']
    expect do
      expect { parser.parse(args) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end.to output(/Usage:/).to_stdout
  end

  it 'parses no-agg option with -A' do
    args = ['-A', '-e', 'test']
    options = parser.parse(args)
    expect(options.no_agg).to be true
  end

  it 'parses no-agg option with --no-agg' do
    args = ['--no-agg', '-e', 'test']
    options = parser.parse(args)
    expect(options.no_agg).to be true
  end

  it 'parses no-color option with -C' do
    args = ['-C', '-e', 'test']
    options = parser.parse(args)
    expect(options.no_color).to be true
  end

  it 'parses no-color option with --no-color' do
    args = ['--no-color', '-e', 'test']
    options = parser.parse(args)
    expect(options.no_color).to be true
  end

  it 'defaults no-agg and no-color to false' do
    args = ['-e', 'test']
    options = parser.parse(args)
    expect(options.no_agg).to be false
    expect(options.no_color).to be false
  end
end
