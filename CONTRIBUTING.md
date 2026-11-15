# Contributing

Bug reports, fixes and focused improvements are welcome.

## Issues

Search existing issues first. Include the app version or commit, platform,
architecture, steps, expected result and actual result. Remove credentials,
private media paths, server addresses and personal content from logs.
Report security issues privately; see [SECURITY.md](SECURITY.md).

## Pull requests

1. Discuss large features or architecture changes in an issue first.
2. Prepare the sibling dependencies described in [README.md](README.md).
   Some currently require private repository access.
3. Keep changes focused. Separate widgets, business services, source adapters
   and native playback responsibilities; use existing UI tokens and components.
4. Update relevant tests and run `flutter analyze` and `flutter test`.
   Native/player changes also need relevant integration tests; state which
   platforms and devices were actually checked.
5. Update both README languages when behavior, setup or limitations change.
   Add user-facing strings to the ARB files and regenerate with `flutter gen-l10n`.
6. Treat persisted configuration, MCP tool schemas and native C ABIs as
   contracts; explain compatibility and migration implications.

Never commit `.env`, populated debug seeds, databases, private media, signing
material or tokens. Use synthetic fixtures and fake services for routine tests.
Live-service tests must remain explicitly enabled.

Unless explicitly agreed otherwise, contributions of original application
code and documentation are provided under MIT, the project
license in [LICENSE](LICENSE). Only submit work you have the right to license.
Preserve upstream notices and update [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
when dependencies change.
