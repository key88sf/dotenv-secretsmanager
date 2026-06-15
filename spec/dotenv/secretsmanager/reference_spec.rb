# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotenv::SecretsManager::Reference do
  describe ".reference?" do
    it "is true only when the value starts with the aws-sm: scheme" do
      expect(described_class.reference?("aws-sm:firstquote/master-key")).to be(true)
    end

    it "is false when aws-sm: is not at the start" do
      expect(described_class.reference?("prefix-aws-sm:foo")).to be(false)
    end

    it "is false for non-string and plain values" do
      expect(described_class.reference?("info")).to be(false)
      expect(described_class.reference?(nil)).to be(false)
    end
  end

  describe "parsing a whole-secret reference (no key selector)" do
    subject(:ref) { described_class.parse("aws-sm:firstquote/master-key") }

    it "captures the secret id and a nil json key" do
      expect(ref.secret_id).to eq("firstquote/master-key")
      expect(ref.json_key).to be_nil
      expect(ref.malformed?).to be(false)
    end
  end

  describe "parsing a JSON-key reference" do
    subject(:ref) { described_class.parse("aws-sm:firstquote/prod|db_password") }

    it "splits secret id from json key" do
      expect(ref.secret_id).to eq("firstquote/prod")
      expect(ref.json_key).to eq("db_password")
      expect(ref.malformed?).to be(false)
    end
  end

  describe "parsing splits on the LAST pipe so ARNs stay intact" do
    subject(:ref) do
      described_class.parse(
        "aws-sm:arn:aws:secretsmanager:us-east-1:123456789012:secret:firstquote/prod-AbCdEf|db_password"
      )
    end

    it "keeps the full ARN as the secret id" do
      expect(ref.secret_id).to eq(
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:firstquote/prod-AbCdEf"
      )
      expect(ref.json_key).to eq("db_password")
    end
  end

  describe "malformed references" do
    it "flags a value that is exactly the scheme" do
      expect(described_class.parse("aws-sm:").malformed?).to be(true)
    end

    it "flags an empty secret id with a key" do
      expect(described_class.parse("aws-sm:|db_password").malformed?).to be(true)
    end

    it "flags a present-but-empty json key" do
      expect(described_class.parse("aws-sm:firstquote/prod|").malformed?).to be(true)
    end
  end
end
