# frozen_string_literal: true

require 'spec_helper'
require 'lsql/sql_executor'

RSpec.describe Lsql::SqlExecutor do
  describe 'COLORS constant' do
    it 'defines color codes for prompt formatting' do
      expect(Lsql::SqlExecutor::COLORS[:red]).to eq("\033[0;31m")
      expect(Lsql::SqlExecutor::COLORS[:green]).to eq("\033[0;32m")
      expect(Lsql::SqlExecutor::COLORS[:reset]).to eq("\033[0m")
    end

    it 'has frozen color constants' do
      expect(Lsql::SqlExecutor::COLORS).to be_frozen
    end
  end
end