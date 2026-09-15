#!/usr/bin/env sh

MEDIACTL="${SNAP}/usr/bin/media-ctl"
MEDIA_DEVICE=/dev/media0

echo ${SNAP}

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

elif cat /sys/class/video4linux/v4l-subdev*/name | grep -q "ar0234"; then
	# RZ/G3E with the ar0234 CSI camera.
	sensor=$(cat /sys/class/video4linux/v4l-subdev*/name | grep "ar0234" | head -n 1)
	cru_output=$(find_entity "CRU output")
	fmt="UYVY8_1X16/1280x720"

	${MEDIACTL} -d ${MEDIA_DEVICE} -r
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${csi2}':1 -> '${ip}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -l "'${ip}':1 -> '${cru_output}':0 [1]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${sensor}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${csi2}':0 [fmt:${fmt} field:none]"
	${MEDIACTL} -d ${MEDIA_DEVICE} -V "'${ip}':0 [fmt:${fmt} field:none]"

else
	echo "No supported camera sensor (ov5645 or ar0234) found" >&2
	exit 1
fi
