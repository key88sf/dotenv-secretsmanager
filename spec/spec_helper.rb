# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "aws-sdk-secretsmanager"
require "dotenv/secretsmanager"

# A hand-rolled stand-in for Aws::SecretsManager::Client, injected via the
# `client` config seam. Records every secret-id requested so tests can assert
# one-fetch-per-secret-id batching.
class FakeSecretsClient
  attr_reader :requested_ids

  def initialize(secrets: {}, errors: {})
    @secrets = secrets   # secret_id => secret_string (nil simulates a binary secret)
    @errors  = errors    # secret_id => exception instance to raise
    @requested_ids = []
  end

  def get_secret_value(secret_id:)
    @requested_ids << secret_id
    raise @errors[secret_id] if @errors.key?(secret_id)

    Aws::SecretsManager::Types::GetSecretValueResponse.new(
      secret_string: @secrets[secret_id]
    )
  end
end

module AwsErrorHelpers
  # All Secrets Manager service errors descend from Aws::Errors::ServiceError;
  # the resolver only inspects the message, so the base class is sufficient.
  def aws_service_error(message)
    Aws::Errors::ServiceError.new(Seahorse::Client::RequestContext.new, message)
  end
end

RSpec.configure do |config|
  config.include AwsErrorHelpers

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Dotenv::SecretsManager.reset_configuration!
  end
end
