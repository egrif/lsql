require 'spec_helper'
require 'lsql/output_file_manager'

RSpec.describe Lsql::OutputFileManager do
  let(:manager) { described_class.new({}) }

  it 'writes content to a file' do
    file = 'tmp_test.txt'
    manager.write(file, 'hello world')
    expect(File.read(file)).to eq('hello world')
    File.delete(file)
  end

  it 'reads content from a file' do
    file = 'tmp_test.txt'
    File.write(file, 'abc123')
    expect(manager.read(file)).to eq('abc123')
    File.delete(file)
  end
end
