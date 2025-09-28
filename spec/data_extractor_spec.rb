require 'spec_helper'
require 'lsql/data_extractor'

RSpec.describe Lsql::DataExtractor do
  let(:extractor) { described_class.new }

  it 'parses PostgreSQL output into structured format' do
    temp_files = []

    # Create mock temp file data with proper PostgreSQL format
    temp_file1 = double('TempFile', closed?: false, close: nil, path: 'temp1.txt')
    temp_file2 = double('TempFile', closed?: false, close: nil, path: 'temp2.txt')

    temp_files << { env: 'dev', file: temp_file1 }
    temp_files << { env: 'prod', file: temp_file2 }

    # Mock PostgreSQL output format
    psql_output1 = [
      " count |   max_id\n",
      "-------+------------\n",
      "  3912 | 4004420002\n",
      "(1 row)\n"
    ]
    
    psql_output2 = [
      " id | name\n",
      "----+-------\n", 
      "  1 | Alice\n",
      "  2 | Bob\n",
      "(2 rows)\n"
    ]

    # Mock file operations
    allow(File).to receive(:exist?).with('temp1.txt').and_return(true)
    allow(File).to receive(:exist?).with('temp2.txt').and_return(true)
    allow(File).to receive(:size).with('temp1.txt').and_return(100)
    allow(File).to receive(:size).with('temp2.txt').and_return(50)
    allow(File).to receive(:readlines).with('temp1.txt').and_return(psql_output1)
    allow(File).to receive(:readlines).with('temp2.txt').and_return(psql_output2)

    result = extractor.extract_from_temp_files(temp_files)

    expect(result).to be_a(Hash)
    expect(result.keys).to contain_exactly('dev', 'prod')
    
    # Check dev environment data
    expect(result['dev']).to be_an(Array)
    expect(result['dev'].length).to eq(1)
    expect(result['dev'][0]['count']).to eq('3912')
    expect(result['dev'][0]['max_id']).to eq('4004420002')
    
    # Check prod environment data
    expect(result['prod']).to be_an(Array)
    expect(result['prod'].length).to eq(2)
    expect(result['prod'][0]['id']).to eq('1')
    expect(result['prod'][0]['name']).to eq('Alice')
    expect(result['prod'][1]['id']).to eq('2')
    expect(result['prod'][1]['name']).to eq('Bob')
  end

  it 'returns structured data as JSON with environment keys' do
    temp_files = []
    temp_file = double('TempFile', closed?: false, close: nil, path: 'temp.txt')
    temp_files << { env: 'test', file: temp_file }
    
    # Mock PostgreSQL output
    psql_output = [" value\n", "-------\n", "    42\n", "(1 row)\n"]
    
    allow(File).to receive(:exist?).with('temp.txt').and_return(true)
    allow(File).to receive(:size).with('temp.txt').and_return(20)
    allow(File).to receive(:readlines).with('temp.txt').and_return(psql_output)
    
    extractor.extract_from_temp_files(temp_files)
    json_output = extractor.to_json
    
    expect(json_output).to include('"test":')
    expect(json_output).to include('"value": "42"')
  end

  it 'returns raw data hash' do
    temp_files = []
    temp_file = double('TempFile', closed?: false, close: nil, path: 'temp.txt')
    temp_files << { env: 'test', file: temp_file }

    psql_output = [
      " id\n",
      "----\n", 
      " 42\n",
      "(1 row)\n"
    ]

    allow(File).to receive(:exist?).with('temp.txt').and_return(true)
    allow(File).to receive(:size).with('temp.txt').and_return(20)
    allow(File).to receive(:readlines).with('temp.txt').and_return(psql_output)

    extractor.extract_from_temp_files(temp_files)
    hash_output = extractor.to_hash

    expect(hash_output).to be_a(Hash)
    expect(hash_output['test']).to be_an(Array)
    expect(hash_output['test'][0]['id']).to eq('42')
  end

end
