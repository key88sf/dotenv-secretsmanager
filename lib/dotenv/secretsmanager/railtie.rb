# frozen_string_literal: true

require "dotenv/secretsmanager"

module Dotenv
  module SecretsManager
    # Auto-resolves aws-sm: references in a Rails app. Runs in the
    # before_configuration phase, which is after dotenv-rails populates ENV
    # (provided this gem is required after dotenv-rails) and before initializers
    # and database.yml consume the values.
    class Railtie < ::Rails::Railtie
      config.before_configuration do
        Dotenv::SecretsManager.resolve!(ENV)
      end
    end
  end
end
