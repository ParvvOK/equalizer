#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="equalizer"
PLUGIN_SOURCE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PLUGINS_DIR="${HOME}/.config/omarchy/plugins"
TARGET="${PLUGINS_DIR}/${PLUGIN_ID}"
STAGE="${PLUGINS_DIR}/.${PLUGIN_ID}.install.$$"

cleanup() {
  rm -rf -- "${STAGE}"
}
trap cleanup EXIT

command -v omarchy >/dev/null 2>&1 || {
  echo "omarchy is required" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 1
}

echo "Validating ${PLUGIN_SOURCE}..."
omarchy plugin validate "${PLUGIN_SOURCE}"
[[ "$(jq -r '.id' "${PLUGIN_SOURCE}/manifest.json")" == "${PLUGIN_ID}" ]] || {
  echo "manifest id must be ${PLUGIN_ID}" >&2
  exit 1
}

mkdir -p -- "${PLUGINS_DIR}"
rm -rf -- "${STAGE}"
mkdir -- "${STAGE}"
cp -a -- "${PLUGIN_SOURCE}/." "${STAGE}/"
omarchy plugin validate "${STAGE}"

# Never replace a live plugin. Disable it first, and stop if that fails.
if [[ -e "${TARGET}" || -L "${TARGET}" ]]; then
  plugin_list="$(omarchy plugin list --json)"
  if jq -e --arg id "${PLUGIN_ID}" \
      'any(.[]; .id == $id and .enabled == true)' <<<"${plugin_list}" >/dev/null; then
    omarchy plugin disable "${PLUGIN_ID}"
  fi
  rm -rf -- "${TARGET}"
fi

mv -- "${STAGE}" "${TARGET}"
omarchy-shell shell rescanPlugins >/dev/null

echo "Installed ${PLUGIN_ID} at ${TARGET}."
echo "Enable it with: omarchy plugin enable ${PLUGIN_ID} --section right"
