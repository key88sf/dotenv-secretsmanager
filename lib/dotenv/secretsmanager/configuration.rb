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

      def initialize
        @on_error = :raise
        @logger = nil
        @client = nil
      end
    end
  end
end
