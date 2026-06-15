# dotenv-secretsmanager

Use AWS Secrets Manager references in your Ruby dotenv files. A `.env` value that
begins with `aws-sm:` is resolved from AWS Secrets Manager at process boot and
written into `ENV` in place.

## Installation

```ruby
# Gemfile — require AFTER dotenv-rails so ENV is populated first
gem "dotenv-rails"
gem "dotenv-secretsmanager"
```

```sh
bundle install
```

## Reference syntax

```bash
# whole plaintext secret
RAILS_MASTER_KEY=aws-sm:firstquote/master-key

# one key from a JSON secret (all three share a single API call)
DB_PASSWORD=aws-sm:firstquote/prod|db_password
YELP_SECRET=aws-sm:firstquote/prod|yelp_client_secret
TWILIO_TOKEN=aws-sm:firstquote/prod|twilio_auth_token

# non-reference values are left untouched
RAILS_LOG_LEVEL=info
```

`<secret-id>` may be a friendly name or a full ARN. The optional `|<json-key>`
selector is split on the last `|`, so ARNs (full of colons, never pipes) parse
correctly.

## Rails

No wiring needed. The railtie resolves references automatically after
`dotenv-rails` loads and before initializers and `database.yml` run.

## Plain Ruby

```ruby
require "dotenv/secretsmanager"
Dotenv::SecretsManager.resolve!(ENV)
```

## Configuration

```ruby
Dotenv::SecretsManager.configure do |c|
  c.on_error = :raise   # :raise (default) — aggregate all failures, raise once
                        # :warn            — log each failure, leave literal in ENV
  c.logger   = nil      # defaults to Rails.logger if present, else $stderr
  c.client   = nil      # inject a custom Aws::SecretsManager::Client
end
```

Credentials and region come from the standard AWS SDK credential chain. The gem
makes zero AWS calls and builds no client when no references are present.

## Deployment (AWS Lightsail Container Service)

Set only `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` as
plaintext deployment env vars (a least-privilege IAM user with
`secretsmanager:GetSecretValue` scoped to your secrets). Put everything else in
`.env.production` as `aws-sm:` references. Keep `.env.development` free of
references so local development needs no AWS access.
