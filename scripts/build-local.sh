#!/usr/bin/env bash
#
# Build this ZMK config locally in Docker, without installing a toolchain.
#
# Usage:
#   scripts/build-local.sh <name> <board> [extra cmake args...]
#   SNIPPET=<snippet> scripts/build-local.sh <name> <board> [extra cmake args...]
#
# Examples:
#   # the two real firmwares
#   SNIPPET=studio-rpc-usb-uart scripts/build-local.sh left eyelash_sofle_left \
#       -DSHIELD=nice_view_custom -DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_STUDIO_LOCKING=n
#   scripts/build-local.sh right eyelash_sofle_right -DSHIELD=nice_view_custom
#
#   # settings reset (wipes NVS *and* all BLE bonds - re-pair both halves after)
#   scripts/build-local.sh reset eyelash_sofle_left -DSHIELD=settings_reset
#
#   # debugging: USB console on the left half, plus LVGL and display-driver logs.
#   # zmk-usb-logging and studio-rpc-usb-uart both claim the CDC ACM console and
#   # cannot be combined, so a logging build has no ZMK Studio.
#   SNIPPET=zmk-usb-logging scripts/build-local.sh debug eyelash_sofle_left \
#       -DSHIELD=nice_view_custom -DCONFIG_LV_USE_LOG=y -DCONFIG_LV_LOG_LEVEL_WARN=y \
#       -DCONFIG_LV_LOG_PRINTF=y -DCONFIG_DISPLAY_LOG_LEVEL_DBG=y
#
# Read the console with:  stty -F /dev/ttyACM1 raw -echo 115200 && cat /dev/ttyACM1
# Resetting the board re-enumerates USB, so wrap that in a reopen loop if you want
# to capture boot messages.
#
# Flash: double-tap the reset button, then copy the .uf2 onto the NICENANO drive.
# Use cp from a terminal - GUI file managers report a spurious error because the
# bootloader reboots and unmounts the drive the moment the write completes.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${ZMK_WEST_WORKSPACE:-$HOME/.cache/zmk-west}"
DOCKER_HOME="${ZMK_DOCKER_HOME:-$HOME/.cache/zmk-docker-home}"

# Must match the Zephyr version that config/west.yml's ZMK revision uses.
# ZMK v0.3 is Zephyr 3.5 + LVGL 8. Do NOT use :stable - it tracks ZMK main,
# which is Zephyr 4.x, and this board is still Hardware Model v1.
IMAGE="${ZMK_DOCKER_IMAGE:-zmkfirmware/zmk-build-arm:3.5-branch}"
SDK="${ZMK_SDK_DIR:-/opt/zephyr-sdk-0.16.3}"

if [ $# -lt 2 ]; then
    sed -n '3,30p' "${BASH_SOURCE[0]}" >&2
    exit 1
fi

name="$1"; board="$2"; shift 2
snippet="${SNIPPET:-}"

# The west topdir lives outside the repo on purpose. west checks Zephyr out at
# <topdir>/zephyr, and this repo already tracks zephyr/module.yml (it declares
# board_root so boards/arm/ is found), so an in-repo workspace buries that file
# under ~700MB of Zephyr sources. Instead: keep the workspace in $WS and
# bind-mount the repo's config/ at $WS/config, which is where the manifest's
# `self: path: config` expects it.
mkdir -p "$WS" "$DOCKER_HOME"

docker_run() {
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -e HOME=/home/build \
        -e ZEPHYR_BASE=/ws/zephyr \
        -e ZEPHYR_TOOLCHAIN_VARIANT=zephyr \
        -e ZEPHYR_SDK_INSTALL_DIR="$SDK" \
        -v "$DOCKER_HOME":/home/build \
        -v "$WS":/ws \
        -v "$REPO":/repo \
        -v "$REPO/config":/ws/config \
        -w /ws \
        "$IMAGE" \
        bash -c "git config --global --add safe.directory '*'; $1"
}

# First run: bootstrap the workspace (~1.5GB of Zephyr + modules).
# .west/config is written by hand rather than via `west init -l`, because the
# bind-mounted /ws/config has no .git of its own for west to anchor to.
if [ ! -d "$WS/.west" ]; then
    echo "==> bootstrapping west workspace in $WS (one-off, downloads ~1.5GB)"
    mkdir -p "$WS/.west"
    printf '[manifest]\npath = config\nfile = west.yml\n' > "$WS/.west/config"
    docker_run "west update && west zephyr-export"
fi

# ZMK_EXTRA_MODULES points at the repo root so Zephyr picks up zephyr/module.yml
# and therefore boards/arm/. This mirrors what zmkfirmware's build-user-config.yml
# workflow does when a config repo has a root-level zephyr/module.yml.
docker_run "west build -p -s zmk/app -d /ws/build/$name -b $board ${snippet:+-S $snippet} -- \
    -DZMK_CONFIG=/ws/config \
    -DZMK_EXTRA_MODULES=/repo \
    $*"

uf2="$WS/build/$name/zephyr/zmk.uf2"
echo
if [ -f "$uf2" ]; then
    ls -la "$uf2"
else
    echo "no uf2 produced" >&2
    exit 1
fi
