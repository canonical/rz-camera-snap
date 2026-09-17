# rz-camera-snap

Snap packaging for CSI MIPI camera bring-up on Renesas RZ platforms.

## Supported platforms

The snap now builds as `rz-camera-controller` and supports:

- RZ/G2L with the `ov5645` CSI camera
- RZ/G3E with the `ar0234` CSI camera
- RZ/V2H and RZ/V2N with the `ar0234` CSI camera

It bundles `media-ctl`, `v4l2-ctl`, `gst-launch-1.0`, `gst-discoverer-1.0`,
and helper scripts to configure the media pipeline before capture.

## Build

```bash
snapcraft
```

## Install

The snap currently uses `devmode` confinement:

```bash
sudo snap install --dangerous --devmode rz-camera-controller_*.snap
```

## Configure the camera pipeline

Use the `config` app to detect the attached sensor, select the required media
bus format for the platform, and configure the pipeline on `/dev/media0`.

```bash
rz-camera-controller.config
```

To see the resolutions exposed by the detected platform:

```bash
rz-camera-controller.config --help
```

You can also request a specific supported resolution:

```bash
rz-camera-controller.config 1920x1080
```

The original RZ/G2L + `ov5645` flow keeps its default `1280x960` pipeline.
For `ar0234` platforms, the helper script auto-detects the platform and picks
the proper media bus format and default resolution.

## Run GStreamer

After configuring the camera, use the bundled GStreamer tools from the snap:

```bash
rz-camera-controller.gst-launch --version
rz-camera-controller.gst-discoverer --help
```

The `gst-launch` wrapper also prepares the OMX configuration and Wayland
runtime environment so the pipeline can be used with Ubuntu Frame/Wayland
setups.

## Low-level tools

The snap also exposes:

```bash
rz-camera-controller.media-ctl
rz-camera-controller.v4l2-ctl
```
