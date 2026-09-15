# Keyboard

[Sofle Split (Standard version)](https://de.aliexpress.com/item/1005008176724988.html?spm=a2g0o.order_list.order_list_main.16.186b5c5fNgYmZ1&gatewayAdapt=glo2deu)

## Boards

### Right
- Model: [nice!nano](https://nicekeyboards.com/docs/nice-nano/)
- Board-ID: nRF52840-nicenano
- SoftDevice: S140 version 6.1.1

# Sofle Keymap

Use the [keymap-editor](https://nickcoutsos.github.io/keymap-editor/) to change the key map.

ℹ️ Update the image with the [GitHub action](https://github.com/ElQDuck/zmk-sofle/actions/workflows/draw.yml)
<img src="keymap-drawer/eyelash_sofle.svg" >

# How To Flash Keyboard

1. Build Firmware with [Action: Build ZMK firmware](https://github.com/ElQDuck/zmk-sofle/actions/workflows/build.yml) and download the result files (`firmware.zip`).
  - The zip folder contains up to 3 files:
    - zmk-right
    - zmk-left
    - zmk-settings-reset (read the [troubleshooting](#troubleshooting) for purpose)
2. Turn on the keyboard you want to flash and plug it to the PC.
3. Press 2 times (fast) the reset button (beside the on/off switch) on the keyboard.
  - A USB drive should appear
4. Copy `zmk-right` or `zmk-left` into the USB drive.
  - When the file copy is finished, the Keyboard installs the firmware and restarts automatically.

# Changelog

- 2025/3/30
  1. Increase sleep entry time by 1 hour.
  2. Increase stabilization time Optimize power consumption after sleep.
- 2024/12/21
  1. Added support for zmk-studio (just refresh the left hand to use).
- 2024/10/24
  1. Modified power supply mode to reduce power consumption.
  2. Fixed the automatic shut-off feature for RGB power supply.

# TODO: migrate to Zephyr 4.x / LVGL 9

`config/west.yml` pins ZMK to the `v0.3` release branch (Zephyr 3.5, LVGL 8). It used to track `main`, which since [`c06fa48c`](https://github.com/zmkfirmware/zmk/commit/c06fa48c) (2025-12-10, "feat!: Move to zephyr v4.1") is Zephyr 4.x. Two things in this repo break against that, so moving back to `main` is a project, not a version bump:

- **Board layout.** `boards/arm/eyelash_sofle/` is Hardware Model v1 (`Kconfig.board`, `board.cmake`, `eyelash_sofle.yaml`). Zephyr 4.x only supports HWMv2, so the board needs porting to `board.yml` + `Kconfig.eyelash_sofle`, or converting into a shield on `nice_nano_v2` the way [upstream did](https://github.com/a741725193/zmk-sofle/commit/4848e21).
- **Display widgets.** The `nice_view_custom` widgets in [ElQDuck/nice-view-mod](https://github.com/ElQDuck/nice-view-mod) are written against the LVGL 8 canvas API. LVGL 9 removes it: `lv_canvas_draw_rect` / `lv_canvas_draw_text` become `lv_layer_t` plus `lv_draw_*`, and `LV_IMG_CF_TRUE_COLOR` becomes `LV_COLOR_FORMAT_*`.

Upstream `a741725193/zmk-sofle@main` is not a shortcut here: since the dyastudio restructure its shield overlays `#include <behaviors/battery_history_request.dtsi>` and `<input/processors/runtime-input-processor.dtsi>`, which only exist in [cormoran](https://github.com/cormoran)'s ZMK fork and modules. Adopting it means giving up stock `zmkfirmware/zmk`.

# Building Locally

The GitHub action is still the normal way to build, but `scripts/build-local.sh` builds the same firmware on your machine in Docker, with no toolchain to install. Turnaround is about a minute instead of a CI round trip, and it is the only practical way to iterate on display or driver debugging.

Requires Docker, and your user in the `docker` group. The first run downloads roughly 1.5GB of Zephyr and its modules into `~/.cache/zmk-west` (override with `ZMK_WEST_WORKSPACE`); later runs reuse it.

```sh
# the two real firmwares
SNIPPET=studio-rpc-usb-uart scripts/build-local.sh left eyelash_sofle_left \
    -DSHIELD=nice_view_custom -DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_STUDIO_LOCKING=n
scripts/build-local.sh right eyelash_sofle_right -DSHIELD=nice_view_custom
```

The `.uf2` lands in `~/.cache/zmk-west/build/<name>/zephyr/zmk.uf2`. Flash it the usual way — double-tap reset, then **copy it with `cp` from a terminal**. GUI file managers report a spurious "error getting information for file" because the bootloader reboots and unmounts the drive the instant the write finishes; the flash actually succeeded.

The build image is pinned to `zmkfirmware/zmk-build-arm:3.5-branch`, matching the Zephyr 3.5 that ZMK `v0.3` uses. Do not use `:stable` — it tracks ZMK `main` and is Zephyr 4.x, which cannot build this board (see the migration TODO above).

## Debugging with a USB console

The left half can log over USB CDC ACM. Note that `zmk-usb-logging` and `studio-rpc-usb-uart` both claim that console, so a logging build has no ZMK Studio.

```sh
SNIPPET=zmk-usb-logging scripts/build-local.sh debug eyelash_sofle_left \
    -DSHIELD=nice_view_custom \
    -DCONFIG_LV_USE_LOG=y -DCONFIG_LV_LOG_LEVEL_WARN=y -DCONFIG_LV_LOG_PRINTF=y \
    -DCONFIG_DISPLAY_LOG_LEVEL_DBG=y
```

Read it with `stty -F /dev/ttyACM1 raw -echo 115200 && cat /dev/ttyACM1`. Two `ttyACM` devices appear; the console is normally the second. Resetting the board re-enumerates USB and kills an open `cat`, so to capture boot messages, loop:

```sh
while true; do
    [ -c /dev/ttyACM1 ] && { stty -F /dev/ttyACM1 raw -echo 115200; cat /dev/ttyACM1; }
    sleep 0.05
done | tee boot.log
```

# Contact

For 3D printed model files or any issues and malfunctions with the keyboard, please contact 380465425@qq.com

# Additional links
- [EurKEY The European Keyboard Layout](https://eurkey.steffen.bruentjen.eu/start.html)
- [Keyboard Layout Editor](https://keyboard-layout-editor.com/#/)
- [How to create a display animation](https://github.com/GPeye/urchin-peripheral-animation)
  - [Image Collection & Slideshow](https://github.com/GPeye/hammerbeam-slideshow)
  - [Mario Animation](https://github.com/GPeye/mario-peripheral-animation)
- [ZMK: List of keycodes](https://zmk.dev/docs/keymaps/list-of-keycodes)

# Troubleshooting
- [split-keyboard-halves-unable-to-pair](https://zmk.dev/docs/troubleshooting/connection-issues#split-keyboard-halves-unable-to-pair)