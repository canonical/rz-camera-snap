#!/usr/bin/env sh

MEDIACTL="${SNAP}/usr/bin/media-ctl"
MEDIA_DEVICE=/dev/media0

# Pipeline subdevices, discovered by name (same as before).
csi2=$(cat /sys/class/video4linux/v4l-subdev*/name | grep "csi2" | head -n 1)
ip=$(cat /sys/class/video4linux/v4l-subdev*/name | grep "cru-ip" | head -n 1)

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

if cat /sys/class/video4linux/v4l-subdev*/name | grep -q "ov5645"; then
	# RZ/G2L with the ov5645 CSI camera (original behaviour, unchanged).
	sensor=$(cat /sys/class/video4linux/v4l-subdev*/name | grep "ov5645" | head -n 1)
	fmt="UYVY8_2X8/1280x960"

	${MEDIACTL} -d ${MEDIA_DEVICE} -r
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${csi2}':1 -> '${ip}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${csi2}':1 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${sensor}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${ip}':0 [fmt:${fmt} field:none]"

	echo "Camera configured: sensor '${sensor}' on ${MEDIA_DEVICE} at ${fmt}"

elif cat /sys/class/video4linux/v4l-subdev*/name | grep -q "ar0234"; then
	# RZ/G3E, RZ/V2H and RZ/V2N with the ar0234 CSI camera.
	sensor=$(cat /sys/class/video4linux/v4l-subdev*/name | grep "ar0234" | head -n 1)
	cru_output=$(find_entity "CRU output")

	# The media bus format differs per platform (same heuristic the vendor
	# v4l2_cam_test.sh uses): RZ/V2H and RZ/V2N need UYVY8_2X8, RZ/G3E UYVY8_1X16.
	case "${csi2}:${ip}" in
	*.csi2[0-9]:*|*:*.video[0-9])
		# RZ/V2H and RZ/V2N (V2N does not support 1280x720).
		fmt="UYVY8_2X8/1920x1080"
		;;
	*)
		# RZ/G3E (unchanged).
		fmt="UYVY8_1X16/1280x720"
		;;
	esac

	${MEDIACTL} -d ${MEDIA_DEVICE} -r
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${csi2}':1 -> '${ip}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${ip}':1 -> '${cru_output}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${sensor}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${csi2}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${ip}':0 [fmt:${fmt} field:none]"

	echo "Camera configured: sensor '${sensor}' on ${MEDIA_DEVICE} at ${fmt}"

else
	echo "No supported camera sensor (ov5645 or ar0234) found" >&2
	exit 1
fi
