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

  describe "JSON-key resolution" do
    it "extracts the requested key from a JSON secret" do
      json = '{"db_password":"pw","yelp_client_secret":"ys","twilio_auth_token":"tt"}'
      client = FakeSecretsClient.new(secrets: { "firstquote/prod" => json })
      env = {
        "DB_PASSWORD" => "aws-sm:firstquote/prod|db_password",
        "YELP_SECRET" => "aws-sm:firstquote/prod|yelp_client_secret",
        "TWILIO_TOKEN" => "aws-sm:firstquote/prod|twilio_auth_token"
      }

      resolve(env, config_with(client: client))

      expect(env).to eq(
        "DB_PASSWORD" => "pw",
        "YELP_SECRET" => "ys",
        "TWILIO_TOKEN" => "tt"
      )
    end

    it "coerces non-string JSON values to strings" do
      client = FakeSecretsClient.new(secrets: { "s" => '{"port":5432}' })
      env = { "DB_PORT" => "aws-sm:s|port" }

      resolve(env, config_with(client: client))

      expect(env["DB_PORT"]).to eq("5432")
    end
  end

  describe "batching" do
    it "fetches each distinct secret-id exactly once across many references" do
      json = '{"db_password":"pw","yelp_client_secret":"ys","twilio_auth_token":"tt"}'
      client = FakeSecretsClient.new(secrets: { "firstquote/prod" => json })
      env = {
        "DB_PASSWORD" => "aws-sm:firstquote/prod|db_password",
        "YELP_SECRET" => "aws-sm:firstquote/prod|yelp_client_secret",
        "TWILIO_TOKEN" => "aws-sm:firstquote/prod|twilio_auth_token"
      }

      resolve(env, config_with(client: client))

      expect(client.requested_ids).to eq(["firstquote/prod"])
    end
  end
end
