# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotenv::SecretsManager do
  describe ".resolve! skip flag" do
    # A client double that fails if any method is called, proving no AWS
    # interaction happens on the skip path.
    let(:exploding_client) do
      Class.new do
        def get_secret_value(*)
          raise "AWS client must not be called when skipping"
        end
      end.new
    end

    around do |example|
      original = ENV.fetch("DOTENV_SECRETSMANAGER_SKIP", :unset)
      example.run
    ensure
      if original == :unset
        ENV.delete("DOTENV_SECRETSMANAGER_SKIP")
      else
        ENV["DOTENV_SECRETSMANAGER_SKIP"] = original
      end
    end

    before { ENV.delete("DOTENV_SECRETSMANAGER_SKIP") }

    it "resolves normally when neither flag is set" do
      client = FakeSecretsClient.new(secrets: { "firstquote/master-key" => "mk" })
      described_class.configure { |c| c.client = client }

      env = { "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key" }
      described_class.resolve!(env)

      expect(env["RAILS_MASTER_KEY"]).to eq("mk")
      expect(client.requested_ids).to eq(["firstquote/master-key"])
    end

    it "skips, deletes references, leaves plain keys, and makes no client call when the env var is truthy" do
      ENV["DOTENV_SECRETSMANAGER_SKIP"] = "true"
      described_class.configure { |c| c.client = exploding_client }

      env = {
        "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key",
        "DEFAULT_URL_HOST" => "example.com"
      }

      expect do
        returned = described_class.resolve!(env)
        expect(returned).to be(env)
      end.not_to raise_error

      expect(env).not_to have_key("RAILS_MASTER_KEY")
      expect(env["DEFAULT_URL_HOST"]).to eq("example.com")
    end

    it "skips and deletes references when configuration.skip is true and the env var is unset" do
      described_class.configure do |c|
        c.skip = true
        c.client = exploding_client
      end

      env = {
        "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key",
        "DEFAULT_URL_HOST" => "example.com"
      }

      expect { described_class.resolve!(env) }.not_to raise_error
      expect(env).not_to have_key("RAILS_MASTER_KEY")
      expect(env["DEFAULT_URL_HOST"]).to eq("example.com")
    end

    it "does not skip when the env var is falsy" do
      client = FakeSecretsClient.new(secrets: { "firstquote/master-key" => "mk" })
      described_class.configure { |c| c.client = client }

      env = { "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key" }

      ["", "0", "false"].each do |falsy|
        env["RAILS_MASTER_KEY"] = "aws-sm:firstquote/master-key"
        ENV["DOTENV_SECRETSMANAGER_SKIP"] = falsy
        described_class.resolve!(env)
        expect(env["RAILS_MASTER_KEY"]).to eq("mk")
      end
    end

    it "skips on a case-insensitive, whitespace-padded truthy value" do
      ENV["DOTENV_SECRETSMANAGER_SKIP"] = " TRUE "
      described_class.configure { |c| c.client = exploding_client }

      env = { "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key" }

      expect { described_class.resolve!(env) }.not_to raise_error
      expect(env).not_to have_key("RAILS_MASTER_KEY")
    end
  end
end
