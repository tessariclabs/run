# Tessaric verify

Runs [Tessaric](https://tessaric.io) in GitHub Actions. Tessaric reads your repository's code and tests as they are, works out what every function owes (no undefined behaviour, no panic, every assertion holding, progress) and proves it, or shows the input that breaks it. Nothing of your code runs.

```yaml
name: tessaric
on: [push, pull_request]
jobs:
  verify:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: tessariclabs/run@v0
```

The step installs the release, restores its caches, runs `tessaric verify`, annotates the changed files with what can fail, and writes the report to the job summary. It needs no secret and no extra permission.

## Inputs

| Input | Effect | Default |
| --- | --- | --- |
| `version` | Release to install, as `X.Y.Z` or `latest`. A pinned version never updates itself. | `latest` |
| `args` | Extra arguments for `tessaric verify`, for example `--require-baseline`. | empty |
| `workspace` | The workspace directory, relative to the checkout. | `.` |
| `baselines` | A file written by `tessaric export`, relative to the workspace, imported before `verify`. | empty |
| `shard` | Run only shard `I` of `N` of the tests, as `I/N`. Spread one run over several jobs with a matrix. | empty |
| `nothing-proved` | What a run that proved nothing yet (exit 3) does to the step: `fail` or `pass`. | `fail` |
| `annotations` | Annotate files with what can fail (error), checks that failed (error), drift (warning) and problems in Tessaric itself (notice). | `true` |
| `summary` | Write the report to the job summary. | `true` |
| `cache` | Keep the caches below between runs. | `true` |

## Outputs

| Output | Value |
| --- | --- |
| `exit-code` | The exit code of `tessaric verify`: 0 ok, 1 a check failed or an obligation can fail, 2 could not determine, 3 nothing was checked or nothing was proved yet, 130 interrupted. |
| `version` | The release that ran. |

## Caching

A later run downloads, unpacks, fetches and proves again only what changed. Each layer is keyed by what changes it:

| Layer | Holds | Kept until |
| --- | --- | --- |
| binary | the release itself | the version changes |
| toolchains | the unpacked toolchains | the version changes; components are stored by content, so a new version reuses what it shares with the last |
| dependencies | fetched crates and modules | a lockfile changes |
| store | programs Tessaric built, by content | saved every run, per branch |
| state | the workspace's `.tessaric`: ledger, compiled proofs, analysis | saved every run, per branch, falling back to the default branch |

A failing run still saves its caches. Turn them off with `cache: false`.

## Runners

Releases are published for Linux x86_64 (`ubuntu-*`). The step names the platform when a release has no binary for the runner.

## Versions

`@v0` follows the latest `0.x` of this action. Pin an exact tag such as `@v0.1.0` for a build that never changes, and pin `version` for the Tessaric release.

Documentation: https://tessaric.io/docs/ci
