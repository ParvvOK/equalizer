# Device profiles

Profiles are stored in the versioned `devices` object in `state.json`, keyed by the stable PipeWire `node.name` when available. They are retained when a device disappears. The backend exposes `eqctl device profile DEVICE_ID` for diagnostics; profile assignment is intentionally kept out of the compact v1 panel until a device selector can be wired to the live WirePlumber model without relying on descriptions or transient object IDs.
