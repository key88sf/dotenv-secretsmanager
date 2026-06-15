# frozen_string_literal: true

require_relative "lib/dotenv/secretsmanager/version"

Gem::Specification.new do |spec|
  spec.name        = "dotenv-secretsmanager"
  spec.version     = Dotenv::SecretsManager::VERSION
  spec.authors     = ["key88sf"]
  spec.summary     = "Resolve AWS Secrets Manager references inside .env files at boot."
  spec.description = "Treats .env values beginning with aws-sm: as references to " \
                     "AWS Secrets Manager secrets, resolving them into ENV at process " \
                     "boot. Framework-agnostic core with an optional Rails railtie."
  spec.homepage    = "https://github.com/key88sf/dotenv-secretsmanager"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-secretsmanager", "~> 1"

  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rspec", "~> 3.13"
end
