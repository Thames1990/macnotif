# Handbook maintenance and publication

The handbook is a Jekyll site using Just the Docs. It tracks current `main`,
not a separate documentation release or a versioned copy for each application
release. The live public address is <https://macnotif.mohrworks.com/>.
The source repository is also public, following the owner's explicit decision
at activation to use GitHub Pages without a paid plan.

## Preview and check locally

Use Ruby 3.3 (the CI version; locked dependencies require Ruby >=3.2),
the Bundler version under `BUNDLED WITH` in `Gemfile.lock`, and Python 3.
From the repository root:

```sh
bundle install
bundle exec jekyll serve --host 127.0.0.1
```

Open <http://127.0.0.1:4000/>. Stop the preview before checking production output:

```sh
JEKYLL_ENV=production bundle exec jekyll build
bash tests/handbook.sh
ruby tests/handbook-workflow.rb
```

The standard Jekyll command loads the root `Gemfile`, `Gemfile.lock`, and
`_config.yml`, including repository plugins. The source is `handbook/`, and
the generated destination is `_site/`. Do not publish the repository root or
commit generated output. `tests/handbook.sh` checks the built public output,
not source templates; it also accepts an alternate destination as its first
argument. Always rebuild before checking so stale output cannot pass. It also
runs `tests/handbook-changelog.sh`, which edits only the canonical changelog in
a disposable source tree and rebuilds it to verify the change reaches the
generated page. This additional build needs the same installed bundle and
leaves the working changelog untouched.

When changing dependencies, update and commit `Gemfile.lock` with the Gemfile.
Keep local Ruby and CI aligned. When adding build inputs or changing output
paths, update the workflow and checks together, including the Pages artifact
path. Do not replace the standard build with a separate CI-only renderer.

## Content ownership and review

Detailed public user guides belong in `handbook/`: overview, installation,
CLI usage, and configuration, including appearance, diagnostics, accessibility,
and live reload. Keep a useful quick start in the README, linking to the
live handbook rather than maintaining duplicate detailed guides.

The root `CHANGELOG.md` remains the sole curated release-history source. Render
it during the Jekyll build, including `Unreleased`; never copy entries into a
second changelog or derive release history from commits or PR titles. Preserve
the [curated changelog policy](../CONTRIBUTING.md#curated-changelog) and the
existing application release tooling.

`handbook/_plugins/changelog.rb` reads the root changelog during each build
and generates the navigable `/changelog/` page. Edit only `CHANGELOG.md` to
update release history; no handbook copy needs synchronization.

Because the handbook follows `main`, a guide can describe behavior absent from
the latest installed release. Explicitly label such behavior **Unreleased**
beside the affected setting, option, or example until a release includes it.
There is no version selector. Include new configuration pages and changelog
content in generated-output and search checks as those sections are added;
do not disable checks while waiting for another handbook slice.

Agent instructions, ADRs, maintainer procedures (including this document),
release tooling, and other repository-only material must stay out of both
generated pages and search data. Keep the Jekyll public source boundary
explicit; do not broaden it to the whole repository to include the changelog.

Review the production output and internal links as well as source changes.
For navigation, search, styling, or theme changes, also check the browser:
search for CLI and configuration terms, follow sidebar links, try a narrow
viewport, inspect code blocks, and switch light/dark schemes. Automated output
checks do not prove those interactions work.

## Pull requests and publication

`.github/workflows/handbook.yml` builds and checks every pull request. This
includes fork pull requests: checkout credentials are not persisted, the build
job has only `contents: read`, and no Cloudflare or other publication secrets
are supplied. PR runs do not upload a Pages artifact or run the deploy job.

Every push to `main` rebuilds and checks the production site, uploads `_site`
as a GitHub Pages artifact, and then deploys that checked artifact through
`actions/deploy-pages`. Triggers intentionally have no path filters: a
canonical-changelog-only update, future configuration content, dependency
lockfile, plugin, test, or other build-input change must not be missed. This
also avoids path-filtered required checks leaving PRs pending. Ordinary pushes
to other branches and application release tags do not publish the handbook.

Permissions are denied by default and granted by job. Only the deploy job has
`pages: write` and `id-token: write`; it uses the `github-pages` environment and
does not check out or execute source. Its main-push guard and successful-build
dependency are mandatory. PR runs supersede older runs for the same ref;
main publications are serialized without cancelling an in-progress deployment.
Keep action references pinned to full commit SHAs with version comments, and
keep `persist-credentials: false` on build checkouts.

The workflow contract check covers trigger, permission, and publication guards;
run it when editing the workflow, and run `actionlint` if available. The
production build and public-output checks remain the primary content checks.
The handbook workflow does not finalize release notes, create application
releases, update the Homebrew tap, or modify existing release workflows.

## Hosting and activation

The owner authorized making `Thames1990/macnotif` public on 2026-10-26 rather
than purchasing GitHub Pro for private-repository Pages eligibility. Pages
uses GitHub Actions, the `github-pages` environment permits only `main`, and
the handbook is deployed at <https://macnotif.mohrworks.com/>. The domain uses
a DNS-only CNAME to `thames1990.github.io`, with GitHub-managed TLS and enforced
HTTPS. The existing account-level verification of `mohrworks.com` covers this
subdomain; preserve its verification TXT record.

Future hosting, DNS, or repository-visibility changes require separate owner
authorization. Routine handbook changes do not require reactivation.

Before any hosting change, recheck live settings and resolve conflicting
configuration rather than overwriting it. If the repository is made private
in the future, first confirm the account plan supports Pages from a private
repository and the required deployment-environment controls.

Keep GitHub Actions as the Pages source and restrict the `github-pages`
environment to `main`. Keep the custom domain
`macnotif.mohrworks.com`, with a Cloudflare **DNS-only** CNAME pointing to
`thames1990.github.io`. Cloudflare supplies DNS only, not proxying, caching, or
TLS termination; no Cloudflare credentials belong in this workflow. Use
GitHub-managed certificates and enable enforced HTTPS when provisioning is
ready.

After activation, verify the Pages deployment and its environment URL, DNS-only
resolution, the expected handbook at the custom-domain root, and valid HTTPS.
Also verify navigation, search, narrow-screen layout, and light/dark behavior
on the live site. Until then, a successful build or prepared workflow is not
evidence that the handbook is publicly hosted.
