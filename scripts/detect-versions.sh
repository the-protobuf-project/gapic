#!/usr/bin/env bash
#
# detect-versions.sh — read the upstream version of each vendored GAPIC plugin
# and compare it to the last-released version recorded in .released-versions.json.
#
# Reads versions from in-tree files (NOT git tags), since the Node/Python
# generators are vendored inside monorepos whose git tags are per-library and
# unrelated to the generator's own version.
#
# Outputs, for each plugin, KEY_VERSION and KEY_CHANGED (true/false) to:
#   - stdout (human readable)
#   - $GITHUB_OUTPUT, if set (so the sync workflow can branch on *_changed)
#
# Exit code is always 0; consumers branch on the *_changed outputs.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT}/.released-versions.json"

GO_MANIFEST="${ROOT}/gapic-go/.release-please-manifest.json"
TS_PKG="${ROOT}/gapic-node/core/generator/gapic-generator-typescript/package.json"
PY_SETUP="${ROOT}/gapic-python/packages/gapic-generator/setup.py"

# --- read current upstream versions ---------------------------------------
go_version="$(jq -r '."."' "${GO_MANIFEST}")"
ts_version="$(jq -r '.version' "${TS_PKG}")"
py_version="$(sed -nE 's/^version = "([^"]+)".*/\1/p' "${PY_SETUP}" | head -n1)"

for kv in "go:${go_version}" "ts:${ts_version}" "py:${py_version}"; do
  if [[ -z "${kv#*:}" || "${kv#*:}" == "null" ]]; then
    echo "ERROR: could not read ${kv%%:*} version" >&2
    exit 1
  fi
done

# --- read last released versions (state) ----------------------------------
if [[ -f "${STATE_FILE}" ]]; then
  go_released="$(jq -r '.go // ""' "${STATE_FILE}")"
  ts_released="$(jq -r '.ts // ""' "${STATE_FILE}")"
  py_released="$(jq -r '.py // ""' "${STATE_FILE}")"
else
  go_released="" ts_released="" py_released=""
fi

emit() { # name current released
  local name="$1" cur="$2" rel="$3" changed="false"
  [[ "${cur}" != "${rel}" ]] && changed="true"
  printf '%s: current=%s released=%s changed=%s\n' "${name}" "${cur}" "${rel}" "${changed}"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      printf '%s_version=%s\n' "${name}" "${cur}"
      printf '%s_changed=%s\n' "${name}" "${changed}"
    } >>"${GITHUB_OUTPUT}"
  fi
}

emit go "${go_version}" "${go_released}"
emit ts "${ts_version}" "${ts_released}"
emit py "${py_version}" "${py_released}"
