# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-06-18

### Changed

- When skipping, `resolve!` now **deletes** every `ENV` key whose value is an
  `aws-sm:` reference instead of leaving the literal reference strings in place.
  A raw `aws-sm:` value is never valid for any consumer, and a present-but-invalid
  secret such as `RAILS_MASTER_KEY` breaks boot (e.g. `key must be 16 bytes`),
  whereas an absent key is tolerated. Non-reference inline config (e.g.
  `DEFAULT_URL_HOST`) is left intact. The `DOTENV_SECRETSMANAGER_SKIP` /
  `configuration.skip` plumbing is unchanged.

## [0.2.0] - 2026-06-18

### Added

- Build-time skip flag. Set `DOTENV_SECRETSMANAGER_SKIP` to a truthy value
  (`1`, `true`, `yes`, `on`; case-insensitive, surrounding whitespace ignored)
  or `Dotenv::SecretsManager.configuration.skip = true` to make `resolve!` a
  pure no-op — no AWS calls, no client constructed, `aws-sm:` references left
  untouched in `ENV`. Either source skips; neither set means resolution runs as
  before. Intended for image builds (e.g. `assets:precompile`) that boot the app
  with no AWS region or credentials and need no secrets.

## [0.1.0] - 2026-06-15

### Added

- Initial release. Resolves `aws-sm:` references in `.env` values into `ENV` at
  process boot via AWS Secrets Manager. Framework-agnostic core with an optional
  Rails railtie.

[Unreleased]: https://github.com/key88sf/dotenv-secretsmanager/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/key88sf/dotenv-secretsmanager/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/key88sf/dotenv-secretsmanager/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/key88sf/dotenv-secretsmanager/releases/tag/v0.1.0
