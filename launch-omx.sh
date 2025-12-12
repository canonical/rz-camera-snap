#!/bin/sh

SRC_CONF="$SNAP/etc/xdg/gstomx.conf"
DST_CONF="$SNAP_USER_DATA/gstomx.conf"

sed "s|core-name=.*|core-name=$SNAP/usr/lib/aarch64-linux-gnu/libomxr_core.so|g" "$SRC_CONF" > "$DST_CONF"

export GST_OMX_CONFIG_DIR="$SNAP_USER_DATA"

exec "$@"
