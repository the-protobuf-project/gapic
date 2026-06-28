#!/usr/bin/env bash
#
# setup-repo.sh — one-time bootstrap of the aggregator repo.
#
# Converts the three existing upstream clones (gapic-go, gapic-node,
# gapic-python) into git submodules WITHOUT re-downloading them, wires up the
# remote, and (optionally) creates the GitHub repos + secrets.
#
# Run once, from the repo root. Re-running is safe-ish but intended for a fresh
# setup. Requires: git, gh (authenticated), jq.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="the-protobuf-project"
REPO="gapic"
TAP="homebrew-tap"

if [ ! -d .git ]; then
  echo "==> git init"
  git init -q
  git branch -M main
fi

# Register each existing clone as a submodule gitlink, reusing the on-disk clone
# (no fresh clone of the multi-GB monorepos). .gitmodules already declares them.
for path in gapic-go gapic-node gapic-python; do
  [ -d "$path/.git" ] || { echo "missing clone: $path" >&2; exit 1; }
  sha=$(git -C "$path" rev-parse HEAD)
  echo "==> registering submodule $path @ ${sha:0:10}"
  git rm -r --cached --quiet "$path" 2>/dev/null || true
  git update-index --add --cacheinfo "160000,$sha,$path"
done

# Move each submodule's .git into the superproject's .git/modules.
git submodule absorbgitdirs

echo "==> staging aggregator files"
git add .gitmodules .gitignore .released-versions.json scripts .github README.md 2>/dev/null || true
git commit -q -m "chore: bootstrap GAPIC plugin aggregator" || echo "(nothing to commit)"

# --- optional: create remotes & secrets (comment out if doing manually) ------
if [ "${CREATE_REMOTE:-0}" = "1" ]; then
  echo "==> creating GitHub repos"
  gh repo create "$ORG/$REPO" --private --source . --remote origin --push || \
    git remote add origin "https://github.com/$ORG/$REPO.git"
  gh repo view "$ORG/$TAP" >/dev/null 2>&1 || gh repo create "$ORG/$TAP" --public --add-readme

  echo "==> NOTE: set these secrets on $ORG/$REPO before the first sync:"
  echo "    RELEASE_PAT               (repo scope; pushes tags so release workflows fire)"
  echo "    HOMEBREW_TAP_GITHUB_TOKEN (repo scope on $ORG/$TAP)"
  echo "  e.g.:  gh secret set RELEASE_PAT -R $ORG/$REPO < token.txt"
fi

echo "==> done."
