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
RAILS_MASTER_KEY=aws-sm:myproject/master-key

# one key from a JSON secret (all three share a single API call)
DB_PASSWORD=aws-sm:myproject/prod|db_password
YELP_SECRET=aws-sm:myproject/prod|yelp_client_secret
TWILIO_TOKEN=aws-sm:myproject/prod|twilio_auth_token

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

## Skipping resolution

Set the `DOTENV_SECRETSMANAGER_SKIP` env var (or `configuration.skip`) to skip
resolution: no AWS calls and no client constructed. Instead of resolving them,
`resolve!` **removes** every `ENV` key whose value is an `aws-sm:` reference, so
the net effect is as if those references were never in `ENV`.

This deletion is deliberate: a raw `aws-sm:` value is never valid for any
consumer, and a *present-but-invalid* secret breaks boot. For example, leaving
`RAILS_MASTER_KEY="aws-sm:..."` in `ENV` makes Rails credentials decryption fail
with `ArgumentError: key must be 16 bytes`, whereas an *absent* `RAILS_MASTER_KEY`
is tolerated. Non-reference inline config (e.g. `DEFAULT_URL_HOST`) is left
intact — the build still wants those values.

```sh
DOTENV_SECRETSMANAGER_SKIP=true
```

```ruby
Dotenv::SecretsManager.configure { |c| c.skip = true }
```

- The env var is truthy when it is `1`, `true`, `yes`, or `on`
  (case-insensitive; surrounding whitespace is ignored). Anything else —
  `""`, `0`, `false`, `no`, or unset — does not by itself skip.
- Either source skips: a truthy env var **or** `configuration.skip == true`.
  The config flag skips regardless of the env var.
- The env var is read at call time (when the railtie fires), so it is the right
  knob for build-time use.

The primary use case is an image build that boots the app — for example a Rails
`assets:precompile` step in a Docker build — where there is no AWS region or
credentials and no secrets are needed. Without skipping, constructing the AWS
client raises (e.g. `Aws::Errors::MissingRegionError`) and fails the build. Set
`DOTENV_SECRETSMANAGER_SKIP=true` on that step only. Non-secret `.env`
config still loads normally; only secrets resolution is skipped.

## Deployment (AWS Lightsail Container Service)

Set only `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` as
plaintext deployment env vars (a least-privilege IAM user with
`secretsmanager:GetSecretValue` scoped to your secrets). Put everything else in
`.env.production` as `aws-sm:` references. Keep `.env.development` free of
references so local development needs no AWS access.
