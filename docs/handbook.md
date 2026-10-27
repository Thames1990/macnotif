# Handbook maintenance and publication

The handbook is a Jekyll site using Just the Docs. It tracks current `main`,
not a separate documentation release or a versioned copy for each application
release. The live public address is <https://macnotif.mohrworks.com/>.
The source repository is also public, following the owner's explicit decision
at activation to use GitHub Pages without a paid plan.

## Preview and check locally

Use Ruby 3.3 (the CI version; locked dependencies require Ruby >=3.2),
the Bundler version under `BUNDLED WITH` in `Gemfile.lock`, and Python 3.
From the repository root, run Jekyll commands with `docs/handbook` as the
working directory:

```sh
cd docs/handbook
bundle install
bundle exec jekyll serve --host 127.0.0.1
```

Open <http://127.0.0.1:4000/>. Stop the preview before checking production output:

```sh
cd ../..
(cd docs/handbook && JEKYLL_ENV=production bundle exec jekyll build)
bash tests/handbook.sh
ruby tests/handbook-workflow.rb
```

The standard Jekyll command loads `docs/handbook/Gemfile`,
`docs/handbook/Gemfile.lock`, and `docs/handbook/_config.yml`, including
repository plugins. The public source is `docs/handbook/site/`, and the
generated destination is `docs/handbook/_site/`. Do not publish the repository
root or commit generated output. `tests/handbook.sh` checks the built public
output, not source templates; it also accepts an alternate destination as its
first argument. Always rebuild before checking so stale output cannot pass. It
also runs `tests/handbook-changelog.sh`, which edits only the canonical
changelog in a disposable source tree and rebuilds it to verify the change
reaches the generated page. This additional build needs the same installed
bundle and leaves the working changelog untouched.
The disposable rebuild uses the original handbook bundle and its local Bundler
configuration, so CI's cached gems remain available without copying dependencies
or installing them again.

When changing dependencies, update and commit `docs/handbook/Gemfile.lock` with
the Gemfile. Keep local Ruby and CI aligned. When adding build inputs or
changing output paths, update the workflow and checks together, including the
Pages artifact path. Do not replace the standard build with a separate CI-only
renderer.

## Content ownership and review

Detailed public user guides belong in `docs/handbook/site/`: overview,
installation, CLI usage, and configuration, including appearance, diagnostics,
accessibility, and live reload. Keep a useful quick start in the README,
linking to the live handbook rather than maintaining duplicate detailed guides.

The root `CHANGELOG.md` remains the sole curated release-history source. The
handbook renders its released sections during the Jekyll build and omits
`Unreleased`, which is not part of a Homebrew release. Never copy entries into
a second changelog or derive release history from commits or PR titles. Preserve
the [curated changelog policy](../CONTRIBUTING.md#curated-changelog) and the
existing application release tooling.

`docs/handbook/site/_plugins/changelog.rb` reads the root changelog during each
build and generates the navigable `/changelog/` page. Edit only
`CHANGELOG.md` to update release history; no handbook copy needs synchronization.

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

`.github/workflows/handbook.yml` builds and checks pull requests that change
`docs/**`, `CHANGELOG.md`, `.github/workflows/handbook.yml`, or
`tests/handbook*`. Jekyll
commands run from `docs/handbook`, so the checked output and Pages artifact are
`docs/handbook/_site/`. This includes fork pull requests: checkout credentials
are not persisted, the build job has only `contents: read`, and no Cloudflare
or other publication secrets are supplied. PR runs do not upload a Pages
artifact or run the deploy job.

Pushes to `main` matching the same path filters rebuild and check the production
site, upload `docs/handbook/_site/` as a GitHub Pages artifact, and then deploy that
checked artifact through `actions/deploy-pages`. These filters include
canonical-changelog-only updates, documentation, dependency lockfiles, plugins,
and handbook checks while skipping unrelated application changes. When adding
build inputs or checks outside these paths, extend both trigger filters and the
workflow contract test. Do not make the path-filtered handbook check a required
PR check: GitHub leaves skipped required checks pending. Ordinary pushes
to other branches and application release tags do not publish the handbook.

Use `workflow_dispatch` for a manual rebuild without changing a file. Manual
runs on `main` also publish the checked artifact; manual runs on other branches
only build and check, with no Pages artifact upload or deployment.

Permissions are denied by default and granted by job. Only the deploy job has
`pages: write` and `id-token: write`; it uses the `github-pages` environment and
does not check out or execute source. Its main-only push/manual guard and successful-build
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
