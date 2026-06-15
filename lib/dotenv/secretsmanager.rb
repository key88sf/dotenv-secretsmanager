# frozen_string_literal: true

require "dotenv/secretsmanager/version"
require "dotenv/secretsmanager/errors"
require "dotenv/secretsmanager/configuration"
require "dotenv/secretsmanager/reference"
require "aws-sdk-secretsmanager"
require "dotenv/secretsmanager/resolver"

module Dotenv
  module SecretsManager
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
        configuration
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
