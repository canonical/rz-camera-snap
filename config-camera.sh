#!/usr/bin/env sh

MEDIACTL="${SNAP}/usr/bin/media-ctl"
MEDIA_DEVICE=/dev/media0

arg="${1:-}"

# Find a media entity by a name substring from the media topology.
find_entity() {
	${MEDIACTL} -d ${MEDIA_DEVICE} --print-topology 2>/dev/null | awk -v pattern="$1" '
		/^- entity [0-9]+:/ {
			name = $0
			sub(/^- entity [0-9]+: /, "", name)
			sub(/ \([0-9]+ pad.*$/, "", name)
			if (index(name, pattern)) {
				print name
				exit
			}
		}'
}

# Pipeline subdevices, discovered by name (same as before).
names=$(cat /sys/class/video4linux/v4l-subdev*/name 2>/dev/null)
csi2=$(printf '%s\n' "$names" | grep "csi2" | head -n 1)
ip=$(printf '%s\n' "$names" | grep "cru-ip" | head -n 1)

# Detect the sensor and platform, and set the media bus format, the list of
# supported resolutions and the default resolution accordingly.
if printf '%s\n' "$names" | grep -q "ov5645"; then
	# RZ/G2L with the ov5645 CSI camera (original behaviour, unchanged).
	cameratype="ov5645"
	platform="RZ/G2L (ov5645)"
	sensor=$(printf '%s\n' "$names" | grep "ov5645" | head -n 1)
	mbus="UYVY8_2X8"
	reslist="1280x960"
	default_res="1280x960"

elif printf '%s\n' "$names" | grep -q "ar0234"; then
	# RZ/G3E, RZ/V2H and RZ/V2N with the ar0234 CSI camera.
	cameratype="ar0234"
	sensor=$(printf '%s\n' "$names" | grep "ar0234" | head -n 1)
	cru_output=$(find_entity "CRU output")

	# The media bus format differs per platform (same heuristic the vendor
	# v4l2_cam_test.sh uses): RZ/V2H and RZ/V2N need UYVY8_2X8, RZ/G3E UYVY8_1X16.
	case "${csi2}:${ip}" in
	*.csi2[0-9]:*|*:*.video[0-9])
		# RZ/V2H and RZ/V2N. They share this branch; see --help for the
		# resolutions each one supports (RZ/V2N does not support 1280x720).
		mbus="UYVY8_2X8"
		platform="RZ/V2H or RZ/V2N (ar0234)"
		reslist="1280x720 1920x1080 1920x1200"
		default_res="1920x1080"
		;;
	*)
		# RZ/G3E (unchanged).
		mbus="UYVY8_1X16"
		platform="RZ/G3E (ar0234)"
		reslist="1280x720 1920x1080 1920x1200"
		default_res="1280x720"
		;;
	esac

else
	echo "No supported camera sensor (ov5645 or ar0234) found" >&2
	exit 1
fi

# --help / -h: list the resolutions available on this platform and exit.
if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
	echo "Usage: $(basename "$0") [RESOLUTION]"
	echo
	echo "Configure the CSI camera pipeline on ${MEDIA_DEVICE}."
	echo "With no RESOLUTION the platform default is used."
	echo
	echo "Detected platform: ${platform}"
	echo "Detected sensor:   ${sensor}"
	echo "Available resolutions:"
	for r in $reslist; do
		if [ "$r" = "$default_res" ]; then
			echo "  ${r} (default)"
		else
			echo "  ${r}"
		fi
	done
	exit 0
fi

# Pick the resolution: default when no argument, otherwise validate it against
# the platform's supported list.
if [ -z "$arg" ]; then
	resolution="$default_res"
else
	resolution=""
	for r in $reslist; do
		if [ "$r" = "$arg" ]; then
			resolution="$r"
			break
		fi
	done
	if [ -z "$resolution" ]; then
		echo "Unsupported resolution '${arg}' for ${platform}." >&2
		echo "Available resolutions:" >&2
		for r in $reslist; do
			echo "  ${r}" >&2
		done
		exit 1
	fi
fi

fmt="${mbus}/${resolution}"

if [ "$cameratype" = "ov5645" ]; then
	${MEDIACTL} -d ${MEDIA_DEVICE} -r
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${csi2}':1 -> '${ip}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${csi2}':1 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${sensor}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${ip}':0 [fmt:${fmt} field:none]"
else
	${MEDIACTL} -d ${MEDIA_DEVICE} -r
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${csi2}':1 -> '${ip}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${ip}':1 -> '${cru_output}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${sensor}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${csi2}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${ip}':0 [fmt:${fmt} field:none]"
fi

echo "Camera configured: sensor '${sensor}' on ${MEDIA_DEVICE} at ${fmt}"
