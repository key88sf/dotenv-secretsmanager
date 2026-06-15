# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Ruby gem that resolves AWS Secrets Manager references inside `.env` files at
process boot. Any `ENV` value beginning with `aws-sm:` is replaced in place with
the resolved secret. The core is framework-agnostic; a Rails railtie wires it in
automatically.

## Commands

```sh
bundle install            # install deps
bundle exec rake spec     # run the full test suite (also `rake` default)
bundle exec rspec spec/dotenv/secretsmanager/resolver_spec.rb          # one file
bundle exec rspec spec/dotenv/secretsmanager/resolver_spec.rb:42       # one example by line
```

Ruby is pinned to 3.3.2 locally (`.ruby-version`); CI tests against 3.0–3.3, and
the gemspec requires `>= 3.0`, so avoid syntax/APIs newer than Ruby 3.0.

## Architecture

Boot flow: `aws-sm:` value in `ENV` → `Resolver#resolve!` → AWS API → `ENV`
overwritten with the resolved string. Entry point `lib/dotenv/secretsmanager.rb`
exposes the singleton API (`configure`, `configuration`, `resolve!`,
`reset_configuration!`).

- **`Reference`** parses one `.env` value. Strips the `aws-sm:` scheme, then
  splits the remainder on the **last** `|` to separate `secret_id` from an
  optional `json_key`. Splitting on the last pipe is deliberate: ARNs are full of
  colons but contain no pipe, so they parse correctly. `malformed?` flags empty
  secret-ids or empty json-keys.
- **`Resolver`** drives a full pass: collects every reference in `ENV`, resolves
  each, and writes results back. Key behaviors:
  - **One API call per distinct secret-id** — results are memoized in
    `@secret_cache`. A *failure* is cached too (stored as a `ResolutionFailure`),
    so repeated references to a broken secret neither refetch nor silently
    succeed.
  - **Error aggregation** — per-reference failures are collected into `Failure`
    structs across the whole pass, then handled once at the end per the
    `on_error` config: `:raise` (default) raises a single `ResolutionError`
    listing all failures; `:warn` logs each and leaves the literal `aws-sm:`
    value in `ENV`.
  - `ResolutionFailure` is an **internal** control-flow signal and never escapes
    `resolve!`; the only public error type is `ResolutionError`.
  - The AWS client is built **lazily** — zero AWS calls and no client when no
    references are present.
- **`Configuration`** holds three seams, all resolved at use time: `on_error`,
  `logger` (defaults to `Rails.logger` if present, else a `$stderr` Logger), and
  `client` (defaults to a real `Aws::SecretsManager::Client`).
- **`Railtie`** resolves references in `before_configuration`, i.e. after
  `dotenv-rails` populates `ENV` and before initializers/`database.yml` consume
  it. This depends on `dotenv-secretsmanager` being required **after**
  `dotenv-rails` in the Gemfile.

## Testing

Specs inject a `FakeSecretsClient` (defined in `spec/spec_helper.rb`) via the
`config.client` seam — no real AWS calls. It records every requested secret-id so
tests can assert the one-fetch-per-secret-id batching. `spec_helper` resets the
singleton configuration before each example (`reset_configuration!`), so always
configure through `Dotenv::SecretsManager.configure` rather than mutating global
state directly. The railtie spec stubs a minimal `Rails::Railtie` so it loads
without Rails.

## Releasing

Published to RubyGems as `dotenv-secretsmanager`. To cut a release:

1. Bump `VERSION` in `lib/dotenv/secretsmanager/version.rb` (SemVer: patch for
   fixes, minor for backward-compatible features, major for breaking changes).
2. Move the `[Unreleased]` notes in `CHANGELOG.md` into a new version section and
   add its compare-link at the bottom.
3. Commit, then `bundle exec rake release` (from `bundler/gem_tasks`, wired in the
   `Rakefile`). This tags `vX.Y.Z`, builds, and pushes to RubyGems in one step,
   and refuses to run on a dirty tree.

A published version number can never be reused — `gem yank` pulls a bad version
from distribution but does **not** free the number, so always bump forward.
RubyGems MFA prompts for an OTP at push time, so run `rake release`
interactively.

## Design docs

`docs/specs/` and `docs/superpowers/plans/` contain the original design spec and
implementation plan — useful background, not authoritative over the current code.
