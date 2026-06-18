# frozen_string_literal: true

require "dotenv/secretsmanager/version"
require "dotenv/secretsmanager/errors"
require "dotenv/secretsmanager/configuration"
require "dotenv/secretsmanager/reference"
require "aws-sdk-secretsmanager"
require "dotenv/secretsmanager/resolver"

module Dotenv
  module SecretsManager
    SKIP_ENV_VAR = "DOTENV_SECRETSMANAGER_SKIP"

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

      def resolve!(env = ENV)
        if skip?
          # Delete reference-holding keys rather than leaving them: a raw
          # aws-sm: literal is never a valid value for any consumer, and a
          # present-but-invalid secret (e.g. RAILS_MASTER_KEY) breaks boot.
          # Non-reference inline config is left intact for the build.
          env.keys.each { |key| env.delete(key) if Reference.reference?(env[key]) }
          return env
        end

        Resolver.new(env: env, config: configuration).resolve!
      end

      # Skip resolution entirely. Either the env var or the config flag can
      # request it; resolution happens only when neither does. Read at call
      # time so a railtie firing during an image build honors the env var.
      def skip?
        truthy?(ENV[SKIP_ENV_VAR]) || configuration.skip
      end

      private

      def truthy?(value)
        return false if value.nil?

        %w[1 true yes on].include?(value.strip.downcase)
      end
    end
  end
end

require "dotenv/secretsmanager/railtie" if defined?(Rails::Railtie)
