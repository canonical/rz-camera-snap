#!/bin/sh

SRC_CONF="$SNAP/etc/xdg/gstomx.conf"
DST_CONF="$SNAP_USER_DATA/gstomx.conf"

sed "s|core-name=.*|core-name=$SNAP/usr/lib/aarch64-linux-gnu/libomxr_core.so|g" "$SRC_CONF" > "$DST_CONF"

export GST_OMX_CONFIG_DIR="$SNAP_USER_DATA"

# Derive the Wayland runtime dir from whoever launches the app instead of
# hardcoding uid 1000. On Ubuntu Server the app runs as the 'ubuntu' user
# (uid 1000 -> /run/user/1000); on Ubuntu Core it runs as root against the
# Frame service (uid 0 -> /run/user/0). Only fill it in if the session did
# not already provide a value.
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

# Bridge Frame's Wayland socket into the snap's confined runtime dir.
# snapd remaps XDG_RUNTIME_DIR to /run/user/<uid>/snap.<name>, but Ubuntu
# Frame publishes its socket one level up at /run/user/<uid>/wayland-0.
# Link it in so waylandsink can find it. Assumes Frame is already running.
# WAYLAND_DISPLAY is provided by the app environment in snapcraft.yaml.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
	ln -sf "$(dirname "$XDG_RUNTIME_DIR")/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
fi

exec "$@"
