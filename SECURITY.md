# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's **Security → Report a
vulnerability** when available. If private reporting is unavailable, contact
a maintainer using their published GitHub profile contact details; do not
post exploit details or credentials in a public issue.

Include the affected commit/build, platform, reproduction steps and impact.
Use synthetic data and redact tokens, media URLs, private paths and databases.
The project is in active development; only the current `main` is maintained.

## Data and deployment boundaries

Source passwords, API keys and service tokens are currently saved in
`configuration.sqlite3`, without a separate OS keychain or application-level
database encryption. Keep app data and backups private. Development schema
changes may discard older data.

Review model data-sharing consent and tool confirmations. External MCP
services and web content are separate trust boundaries. Use HTTPS and
scoped tokens for remote services; keep signing material, `.env` and populated
debug seeds outside Git. Optional diagnostics are described in [SENTRY.md](SENTRY.md).
