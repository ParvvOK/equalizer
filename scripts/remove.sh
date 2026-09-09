#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="equalizer"
PLUGINS_DIR="${HOME}/.config/omarchy/plugins"
TARGET="${PLUGINS_DIR}/${PLUGIN_ID}"

# eqctl writes these two paths outside the plugin directory, so deleting TARGET
# alone leaves the filter-chain sink in the user's output list permanently.
# Keep them in sync with CONFIG_HOME, ROOT and WP_FRAGMENT in backend/eqctl.
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
STATE_DIR="${CONFIG_HOME}/omarchy/equalizer"
WP_FRAGMENT="${CONFIG_HOME}/wireplumber/wireplumber.conf.d/omarchy-equalizer.conf"

KEEP_STATE=0
for arg in "$@"; do
  case "${arg}" in
  --keep-state) KEEP_STATE=1 ;;
  *)
    echo "usage: $(basename -- "$0") [--keep-state]" >&2
    exit 2
    ;;
  esac
done

if [[ -e "${TARGET}" || -L "${TARGET}" ]]; then
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
  echo "Removed plugin files from ${TARGET}."
elif [[ -f "${WP_FRAGMENT}" || -d "${STATE_DIR}" ]]; then
  # State left behind by an earlier remove.sh, or by deleting TARGET by hand.
  echo "${PLUGIN_ID} is not installed at ${TARGET}; cleaning up what it left behind."
else
  echo "${PLUGIN_ID} is not installed."
  exit 0
fi

# Dropping the fragment and restarting WirePlumber is what actually removes the
# "Omarchy Equalizer" entry from the user's audio output list.
if [[ -f "${WP_FRAGMENT}" ]]; then
  rm -f -- "${WP_FRAGMENT}"
  echo "Removed WirePlumber fragment ${WP_FRAGMENT}."
  if systemctl --user restart wireplumber.service; then
    echo "Restarted WirePlumber; the Omarchy Equalizer sink is gone."
  else
    echo "Could not restart WirePlumber. The sink stays until you run:" >&2
    echo "  systemctl --user restart wireplumber.service" >&2
  fi
fi

if ((KEEP_STATE)); then
  echo "Kept equalizer state and user presets in ${STATE_DIR}."
elif [[ -d "${STATE_DIR}" ]]; then
  rm -rf -- "${STATE_DIR}"
  echo "Removed equalizer state from ${STATE_DIR}."
fi

echo "Removal of ${PLUGIN_ID} complete."
