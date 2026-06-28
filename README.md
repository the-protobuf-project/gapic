# GAPIC plugin distribution

Aggregates Google's three GAPIC code-generator **protoc plugins** and
re-distributes prebuilt binaries/packages under the
[`the-protobuf-project`](https://github.com/the-protobuf-project) org — via
**GitHub Releases + Homebrew**. No generator code is authored or maintained
here; upstream sources are tracked as pristine git submodules.

| Plugin | Submodule | Built from | Binary | Homebrew |
|---|---|---|---|---|
| Go | `gapic-go` | `cmd/protoc-gen-go_gapic` | `protoc-gen-go_gapic` | `protoc-gen-go-gapic` (cask) |
| Node/TS | `gapic-node` | `core/generator/gapic-generator-typescript` | `protoc-gen-typescript_gapic` | `protoc-gen-typescript-gapic` (formula) |
| Python | `gapic-python` | `packages/gapic-generator` | `protoc-gen-python_gapic` | `protoc-gen-python-gapic` (formula) |

Each plugin has an **independent version stream** that **mirrors upstream**
(read from `release-please-manifest.json` / `package.json` / `setup.py`), and is
released under its own namespaced tag: `go-v*`, `ts-v*`, `py-v*`.

## How it works

```
schedule (every 3 days) / manual dispatch
        │
        ▼
  .github/workflows/sync.yml
   ├─ git submodule update --remote        (pull latest upstream)
   ├─ scripts/detect-versions.sh           (compare to .released-versions.json)
   └─ for each changed plugin: commit bump + push tag  go-v* / ts-v* / py-v*
        │
        ▼  (tag push, via RELEASE_PAT, fans out to)
  release-go.yml      → GoReleaser → binaries + Homebrew cask
  release-node.yml    → npm build → self-contained tarball + Homebrew formula
  release-python.yml  → python -m build → sdist/wheel + Homebrew formula
        │
        ▼
  GitHub Releases on this repo  +  the-protobuf-project/homebrew-tap
```

## Install (after first release)

```bash
brew install the-protobuf-project/tap/protoc-gen-go-gapic
brew install the-protobuf-project/tap/protoc-gen-typescript-gapic
brew install the-protobuf-project/tap/protoc-gen-python-gapic
```

## One-time setup

1. `bash scripts/setup-repo.sh` — converts the existing clones into submodules
   (no re-download) and commits the aggregator. Set `CREATE_REMOTE=1` to also
   create the GitHub repos.
2. Create `the-protobuf-project/homebrew-tap` (public) if not already.
3. Set repo secrets on `the-protobuf-project/gapic`:
   - `RELEASE_PAT` — PAT (repo scope). Used by `sync.yml` to push tags so the
     release workflows trigger (the default `GITHUB_TOKEN` cannot trigger them).
   - `HOMEBREW_TAP_GITHUB_TOKEN` — PAT (repo scope) on the tap repo.
4. Trigger `sync.yml` manually (Actions → "Sync upstream & release" → Run) for
   the first release; thereafter it runs every ~3 days.

## Manual "sync now"

The GitHub "Sync fork" button only applies to true forks; here the upstreams are
submodules, so use **Actions → Sync upstream & release → Run workflow**, or:

```bash
gh workflow run sync.yml          # or
gh api repos/the-protobuf-project/gapic/dispatches -f event_type=sync
```
