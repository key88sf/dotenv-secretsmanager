# frozen_string_literal: true

module Dotenv
  module SecretsManager
    # Raised (under on_error: :raise) when one or more references cannot be
    # resolved. The message aggregates every failing env var.
    class ResolutionError < StandardError; end
  end
end
