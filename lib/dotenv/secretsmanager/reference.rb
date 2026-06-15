# frozen_string_literal: true

module Dotenv
  module SecretsManager
    # Parses a single .env value into its Secrets Manager components.
    #
    #   aws-sm:<secret-id>             => whole secret string
    #   aws-sm:<secret-id>|<json-key>  => one key from a JSON secret
    #
    # The remainder after the scheme is split on the LAST pipe, so neither a
    # friendly name nor an ARN (which contain no pipe) is ever mis-split.
    class Reference
      SCHEME = "aws-sm:"

      attr_reader :raw, :secret_id, :json_key

      def self.reference?(value)
        value.is_a?(String) && value.start_with?(SCHEME)
      end

      def self.parse(value)
        new(value)
      end

      def initialize(raw)
        @raw = raw
        remainder = raw[SCHEME.length..] || ""

        if remainder.include?("|")
          before, _, after = remainder.rpartition("|")
          @secret_id = before
          @json_key = after
        else
          @secret_id = remainder
          @json_key = nil
        end
      end

      def malformed?
        return true if @secret_id.nil? || @secret_id.empty?
        return true if !@json_key.nil? && @json_key.empty?

        false
      end
    end
  end
end
