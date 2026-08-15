#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="equalizer"
PLUGINS_DIR="${HOME}/.config/omarchy/plugins"
TARGET="${PLUGINS_DIR}/${PLUGIN_ID}"

if [[ ! -e "${TARGET}" && ! -L "${TARGET}" ]]; then
  echo "${PLUGIN_ID} is not installed."
  exit 0
fi

command -v omarchy >/dev/null 2>&1 || {
  echo "omarchy is required to disable the plugin safely" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required to check the plugin state" >&2
  exit 1
}

# Querying the shell must succeed before touching the files. If the plugin is
# enabled, disable must also succeed or deletion is aborted by set -e.
plugin_list="$(omarchy plugin list --json)"
if jq -e --arg id "${PLUGIN_ID}" \
    'any(.[]; .id == $id and .enabled == true)' <<<"${plugin_list}" >/dev/null; then
  omarchy plugin disable "${PLUGIN_ID}"
fi

# TARGET is constructed from a fixed plugin id and is never user-supplied.
rm -rf -- "${TARGET}"
omarchy-shell shell rescanPlugins >/dev/null

echo "Removed all files for ${PLUGIN_ID} from ${TARGET}."
