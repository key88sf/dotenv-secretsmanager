# frozen_string_literal: true

require "json"

module Dotenv
  module SecretsManager
    class Resolver
      Failure = Struct.new(:env_key, :reference, :reason)

      # Internal control-flow signal for a single unresolvable reference.
      # Never escapes resolve!; the public type is ResolutionError.
      class ResolutionFailure < StandardError; end

      def initialize(env:, config:)
        @env = env
        @config = config
        @secret_cache = {}
      end

      def resolve!
        references = collect_references
        return @env if references.empty?

        failures = []
        references.each do |env_key, reference|
          @env[env_key] = resolve_one(reference)
        rescue ResolutionFailure => e
          failures << Failure.new(env_key, reference, e.message)
        end

        handle_failures(failures) unless failures.empty?
        @env
      end

      private

      def collect_references
        @env.keys.each_with_object([]) do |key, acc|
          value = @env[key]
          acc << [key, Reference.parse(value)] if Reference.reference?(value)
        end
      end

      def resolve_one(reference)
        raise ResolutionFailure, "malformed reference" if reference.malformed?

        secret = fetch(reference.secret_id)
        reference.json_key ? extract_json_key(secret, reference) : secret
      end

      # One GetSecretValue per distinct secret-id for the whole pass. A failed
      # fetch is cached as the failure so repeated references neither refetch nor
      # silently succeed.
      def fetch(secret_id)
        @secret_cache[secret_id] = fetch_uncached(secret_id) unless @secret_cache.key?(secret_id)

        result = @secret_cache[secret_id]
        raise result if result.is_a?(ResolutionFailure)

        result
      end

      def fetch_uncached(secret_id)
        response = client.get_secret_value(secret_id: secret_id)
        string = response.secret_string
        return ResolutionFailure.new("secret '#{secret_id}' has no string value") if string.nil?

        string
      rescue Aws::Errors::ServiceError => e
        ResolutionFailure.new("AWS error for '#{secret_id}': #{e.message}")
      end

      def extract_json_key(secret, reference)
        data =
          begin
            JSON.parse(secret)
          rescue JSON::ParserError
            raise ResolutionFailure, "secret '#{reference.secret_id}' is not valid JSON"
          end

        unless data.is_a?(Hash)
          raise ResolutionFailure, "secret '#{reference.secret_id}' is not a JSON object"
        end
        unless data.key?(reference.json_key)
          raise ResolutionFailure,
                "key '#{reference.json_key}' not found in secret '#{reference.secret_id}'"
        end

        data.fetch(reference.json_key).to_s
      end

      def handle_failures(failures)
        if @config.on_error == :warn
          failures.each { |f| logger.warn("[dotenv-secretsmanager] #{failure_line(f)}") }
        else
          raise ResolutionError, build_error_message(failures)
        end
      end

      def failure_line(failure)
        "#{failure.env_key} (#{failure.reference.raw}): #{failure.reason}"
      end

      def build_error_message(failures)
        lines = failures.map { |f| "  - #{failure_line(f)}" }
        "Failed to resolve #{failures.size} Secrets Manager reference(s):\n#{lines.join("\n")}"
      end

      def client
        @client ||= @config.client || Aws::SecretsManager::Client.new
      end

      def logger
        @logger ||= @config.logger || default_logger
      end

      def default_logger
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger
        else
          require "logger"
          Logger.new($stderr)
        end
      end
    end
  end
end
