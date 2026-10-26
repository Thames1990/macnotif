# Contributing

## Handbook

See [handbook maintenance and publication](docs/handbook.md) for local preview,
production checks, content ownership, and the main-only GitHub Pages workflow.
The handbook tracks current `main`; label behavior not yet released rather than
maintaining versioned guides.

## Curated changelog

[CHANGELOG.md](CHANGELOG.md) is the canonical user-facing release history.
For a user-facing change, add a curated entry under `Unreleased` describing
the benefit, fix, or migration requirement for MacNotif users. Breaking changes
must explain what existing users need to change. Do not derive notes from
commit messages or PR titles.

Use `Added`, `Changed`, `Fixed`, and `Breaking Changes` categories where useful,
omitting empty categories. Internal-only maintenance needs no entry; there is
no per-PR changelog CI gate. For an intentional maintenance-only release,
explicitly record "No user-facing changes." under `Unreleased`.

Keep one `Unreleased` section above newest-first released sections. Released
headings use `VERSION - YYYY-MM-DD`, without the tag's `v` prefix. Leave
`Unreleased` empty when there are no upcoming user-facing changes.

## Releases

Follow the [maintainer release procedure](README.md#maintainer-releases).
The manual workflow finalizes the changelog and publishes its selected
version section, as documented in the [release changelog design](docs/release-changelogs.md).
Dispatching a release is the maintainer's approval of its accumulated notes;
there is no separate release-note approval gate.
