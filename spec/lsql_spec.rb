# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lsql do
  it 'has a version number' do
    expect(Lsql::VERSION).not_to be nil
  end
end

RSpec.describe Lsql::Application do
  describe '#initialize' do
    it 'creates a new application instance' do
      app = described_class.new
      expect(app).to be_an_instance_of(described_class)
    end
  end
end
