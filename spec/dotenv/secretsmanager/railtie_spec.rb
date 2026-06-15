# frozen_string_literal: true

require "spec_helper"

# Minimal stand-in for Rails::Railtie so the railtie file loads without Rails
# and we can capture + invoke the before_configuration block.
module Rails
  class Railtie
    class FakeConfig
      attr_reader :captured_block

      def before_configuration(&block)
        @captured_block = block
      end
    end

    def self.config
      Rails::Railtie.instance_variable_get(:@config) ||
        Rails::Railtie.instance_variable_set(:@config, FakeConfig.new)
    end
  end
end

require "dotenv/secretsmanager/railtie"

RSpec.describe Dotenv::SecretsManager::Railtie do
  it "is a Rails::Railtie subclass" do
    expect(described_class.ancestors).to include(Rails::Railtie)
  end

  it "registers a before_configuration hook that calls resolve!(ENV)" do
    block = Rails::Railtie.config.captured_block
    expect(block).not_to be_nil

    allow(Dotenv::SecretsManager).to receive(:resolve!)
    block.call
    expect(Dotenv::SecretsManager).to have_received(:resolve!).with(ENV)
  end
end
