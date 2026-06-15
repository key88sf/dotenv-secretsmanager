# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotenv::SecretsManager::Configuration do
  it "defaults on_error to :raise" do
    expect(described_class.new.on_error).to eq(:raise)
  end

  it "defaults logger and client to nil" do
    config = described_class.new
    expect(config.logger).to be_nil
    expect(config.client).to be_nil
  end

  it "is mutable via accessors" do
    config = described_class.new
    config.on_error = :warn
    expect(config.on_error).to eq(:warn)
  end
end

RSpec.describe Dotenv::SecretsManager do
  it "yields the shared configuration to a configure block" do
    described_class.configure { |c| c.on_error = :warn }
    expect(described_class.configuration.on_error).to eq(:warn)
  end

  it "exposes ResolutionError as a StandardError subclass" do
    expect(Dotenv::SecretsManager::ResolutionError.ancestors).to include(StandardError)
  end
end
