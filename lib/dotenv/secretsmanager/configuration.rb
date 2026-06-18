# frozen_string_literal: true

module Dotenv
  module SecretsManager
    class Configuration
      # :raise (default) | :warn
      attr_accessor :on_error
      # nil => Rails.logger if present, else a $stderr Logger (resolved at use time)
      attr_accessor :logger
      # nil => a default Aws::SecretsManager::Client (built lazily, only if needed)
      attr_accessor :client
      # true => skip resolution entirely (no AWS calls, no client, ENV untouched)
      attr_accessor :skip

      def initialize
        @on_error = :raise
        @logger = nil
        @client = nil
        @skip = false
      end
    end
  end
end
