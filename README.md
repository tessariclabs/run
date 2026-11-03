<p>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/tessaric-banner.svg">
    <img src="assets/tessaric-banner-light.svg" alt="TESSARIC" height="40">
  </picture>
</p>

Proves what your code does on every pull request: no undefined behaviour, no panic, every assertion holding. Nothing of your code runs.

```yaml
permissions:
  contents: read
  pull-requests: write   # for the one comment on the pull request

steps:
  - uses: actions/checkout@v4
  - uses: tessariclabs/run@v0
```

**On the pull request:** one comment, edited on every run, one line unless something can fail. Notes on at most 10 lines that can fail.<br>
**On the run page:** the full report, also kept as `tessaric-report.md` and `.json`.<br>
**Caches:** the binary, toolchains, dependencies and workspace state, so later runs redo only what changed.

| Input | Default | |
| --- | --- | --- |
| `version` | `latest` | release, as `X.Y.Z` |
| `args` | | extra `tessaric verify` arguments |
| `workspace` | `.` | workspace directory |
| `baselines` | | file from `tessaric export` to import first |
| `shard` | | `I/N`: one shard of the tests per job |
| `nothing-proved` | `fail` | `pass` lets a run that proved nothing yet pass |
| `comment`, `annotations`, `summary`, `upload-report`, `cache` | `true` | turn a part off |

Output `exit-code`: 0 ok, 1 something can fail or a check failed, 2 could not determine, 3 nothing proved yet. Runs on Linux x86_64 runners. Docs: [tessaric.io/docs/ci](https://tessaric.io/docs/ci)
