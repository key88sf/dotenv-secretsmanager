# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotenv::SecretsManager::Resolver do
  def config_with(client:, on_error: :raise, logger: nil)
    Dotenv::SecretsManager::Configuration.new.tap do |c|
      c.client = client
      c.on_error = on_error
      c.logger = logger
    end
  end

  def resolve(env, config)
    described_class.new(env: env, config: config).resolve!
  end

  describe "the no-references fast path" do
    it "returns the env unchanged and never builds a client" do
      # config.client is nil; a real client would need a region. We assert no
      # AWS client class is ever instantiated.
      expect(Aws::SecretsManager::Client).not_to receive(:new)

      env = { "RAILS_LOG_LEVEL" => "info", "PORT" => "3000" }
      result = resolve(env, config_with(client: nil))

      expect(result).to eq("RAILS_LOG_LEVEL" => "info", "PORT" => "3000")
    end
  end

  describe "whole-secret resolution" do
    it "substitutes the entire secret string in place" do
      client = FakeSecretsClient.new(secrets: { "firstquote/master-key" => "abc123masterkey" })
      env = { "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key", "RAILS_LOG_LEVEL" => "info" }

      resolve(env, config_with(client: client))

      expect(env["RAILS_MASTER_KEY"]).to eq("abc123masterkey")
      expect(env["RAILS_LOG_LEVEL"]).to eq("info")
      expect(client.requested_ids).to eq(["firstquote/master-key"])
    end

    it "returns the raw JSON string verbatim for a whole-secret reference against a JSON secret" do
      json = '{"db_password":"pw"}'
      client = FakeSecretsClient.new(secrets: { "firstquote/prod" => json })
      env = { "WHOLE" => "aws-sm:firstquote/prod" }

      resolve(env, config_with(client: client))

      expect(env["WHOLE"]).to eq(json)
    end
  end
end
