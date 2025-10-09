# frozen_string_literal: true

require 'spec_helper'
require 'lsql/sql_executor'

RSpec.describe Lsql::SqlExecutor do
  let(:options) { double('options', no_color: false, space: nil, env: 'dev') }
  let(:output_manager) { double('output_manager') }
  let(:database_connector) { double('database_connector', mode_display: '', extract_hostname: 'test-host') }
  let(:sql_executor) { described_class.new(options, output_manager, database_connector) }

  describe 'prompt configuration integration' do
    it 'uses ConfigManager for color settings' do
      allow(LSQL::ConfigManager).to receive(:get_prompt_colors).and_return({
                                                                             'production' => "\033[0;31m",
                                                                             'development' => "\033[0;32m",
                                                                             'reset' => "\033[0m"
                                                                           })

      expect(LSQL::ConfigManager).to receive(:get_prompt_colors)
      sql_executor.send(:build_colored_prompt)
    end
  end

  describe '#execute_interactive' do
    context 'with no-color option' do
      let(:options) { double('options', no_color: true, space: 'prod', env: 'production') }

      context 'with read-write mode (empty mode_display)' do
        let(:database_connector) { double('database_connector', mode_display: '', extract_hostname: 'test-host') }

        it 'creates SPACE:MODE prompt format' do
          allow(sql_executor).to receive(:exec)
          allow(sql_executor).to receive(:puts)
          expected_prompt = 'PROD:RW > production:%/%R%# '
          expect(sql_executor).to receive(:exec).with('psql', 'test-url', "--set=PROMPT1=#{expected_prompt}", "--set=PROMPT2=#{expected_prompt}")
          sql_executor.send(:run_interactive_session, 'test-url')
        end
      end

      context 'with primary read-only mode' do
        let(:database_connector) { double('database_connector', mode_display: '[RO-PRIMARY]', extract_hostname: 'test-host') }

        it 'creates SPACE:R1 prompt format' do
          allow(sql_executor).to receive(:exec)
          allow(sql_executor).to receive(:puts)
          expected_prompt = 'PROD:R1 > production[RO-PRIMARY]:%/%R%# '
          expect(sql_executor).to receive(:exec).with('psql', 'test-url', "--set=PROMPT1=#{expected_prompt}", "--set=PROMPT2=#{expected_prompt}")
          sql_executor.send(:run_interactive_session, 'test-url')
        end
      end

      context 'with secondary read-only mode' do
        let(:database_connector) { double('database_connector', mode_display: '[RO-SECONDARY]', extract_hostname: 'test-host') }

        it 'creates SPACE:R2 prompt format' do
          allow(sql_executor).to receive(:exec)
          allow(sql_executor).to receive(:puts)
          expected_prompt = 'PROD:R2 > production[RO-SECONDARY]:%/%R%# '
          expect(sql_executor).to receive(:exec).with('psql', 'test-url', "--set=PROMPT1=#{expected_prompt}", "--set=PROMPT2=#{expected_prompt}")
          sql_executor.send(:run_interactive_session, 'test-url')
        end
      end

      context 'with dev space' do
        let(:options) { double('options', no_color: true, space: 'dev', env: 'development') }
        let(:database_connector) { double('database_connector', mode_display: '', extract_hostname: 'test-host') }

        it 'creates DEV:RW prompt format' do
          allow(sql_executor).to receive(:exec)
          allow(sql_executor).to receive(:puts)
          expected_prompt = 'DEV:RW > development:%/%R%# '
          expect(sql_executor).to receive(:exec).with('psql', 'test-url', "--set=PROMPT1=#{expected_prompt}", "--set=PROMPT2=#{expected_prompt}")
          sql_executor.send(:run_interactive_session, 'test-url')
        end
      end
    end

    context 'with color enabled (default)' do
      let(:options) { double('options', no_color: false, space: nil, env: 'dev') }
      let(:database_connector) { double('database_connector', mode_display: '', extract_hostname: 'test-host') }

      it 'uses colored prompt format' do
        allow(sql_executor).to receive(:exec)
        allow(sql_executor).to receive(:puts)
        expected_prompt = "\u000033[0;32mdev:%/%R%#\u000033[0m "
        expect(sql_executor).to receive(:exec).with('psql', 'test-url', "--set=PROMPT1=#{expected_prompt}", "--set=PROMPT2=#{expected_prompt}")
        sql_executor.send(:run_interactive_session, 'test-url')
      end
    end
  end
end
