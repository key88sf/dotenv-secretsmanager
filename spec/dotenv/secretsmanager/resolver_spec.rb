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

  describe "on_error: :raise (default)" do
    it "aggregates every failure into a single ResolutionError naming each env var" do
      client = FakeSecretsClient.new(
        secrets: { "good" => '{"k":"v"}' },
        errors: { "missing" => aws_service_error("Secrets Manager can't find the specified secret.") }
      )
      env = {
        "FOUND" => "aws-sm:good|k",
        "GONE" => "aws-sm:missing",
        "NO_KEY" => "aws-sm:good|absent",
        "BAD_REF" => "aws-sm:"
      }

      expect { resolve(env, config_with(client: client, on_error: :raise)) }
        .to raise_error(Dotenv::SecretsManager::ResolutionError) { |e|
          expect(e.message).to include("GONE")
          expect(e.message).to include("NO_KEY")
          expect(e.message).to include("BAD_REF")
          expect(e.message).to include("3 Secrets Manager reference(s)")
        }
    end

    it "fails when a |key is requested against a non-JSON secret" do
      client = FakeSecretsClient.new(secrets: { "plain" => "not-json" })
      env = { "X" => "aws-sm:plain|key" }

      expect { resolve(env, config_with(client: client)) }
        .to raise_error(Dotenv::SecretsManager::ResolutionError, /not valid JSON/)
    end

    it "fails when the secret has no string value (binary secret)" do
      client = FakeSecretsClient.new(secrets: { "bin" => nil })
      env = { "X" => "aws-sm:bin" }

      expect { resolve(env, config_with(client: client)) }
        .to raise_error(Dotenv::SecretsManager::ResolutionError, /no string value/)
    end
  end

  describe "on_error: :warn" do
    it "logs each failure and leaves the original literal untouched" do
      logger = instance_double("Logger")
      allow(logger).to receive(:warn)
      client = FakeSecretsClient.new(
        errors: { "missing" => aws_service_error("not found") }
      )
      env = { "GONE" => "aws-sm:missing", "PLAIN" => "keepme" }

      result = resolve(env, config_with(client: client, on_error: :warn, logger: logger))

      expect(result["GONE"]).to eq("aws-sm:missing")
      expect(result["PLAIN"]).to eq("keepme")
      expect(logger).to have_received(:warn).with(/GONE.*aws-sm:missing.*not found/)
    end

    it "still substitutes the references that DID resolve" do
      logger = instance_double("Logger")
      allow(logger).to receive(:warn)
      client = FakeSecretsClient.new(
        secrets: { "good" => "value" },
        errors: { "missing" => aws_service_error("not found") }
      )
      env = { "OK" => "aws-sm:good", "GONE" => "aws-sm:missing" }

      resolve(env, config_with(client: client, on_error: :warn, logger: logger))

      expect(env["OK"]).to eq("value")
      expect(env["GONE"]).to eq("aws-sm:missing")
    end
  end
end
