# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotenv::SecretsManager do
  describe ".resolve!" do
    it "resolves references in the given env using the shared configuration" do
      client = FakeSecretsClient.new(secrets: { "firstquote/master-key" => "mk" })
      described_class.configure { |c| c.client = client }

      env = { "RAILS_MASTER_KEY" => "aws-sm:firstquote/master-key" }
      returned = described_class.resolve!(env)

      expect(env["RAILS_MASTER_KEY"]).to eq("mk")
      expect(returned).to be(env)
    end

    it "defaults the env argument to ENV" do
      described_class.configure { |c| c.client = FakeSecretsClient.new }
      # No aws-sm: references in the real ENV during the suite => fast path,
      # returns ENV without raising.
      expect { described_class.resolve! }.not_to raise_error
    end
  end
end
