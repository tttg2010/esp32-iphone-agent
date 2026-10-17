#!/usr/bin/env bash
# Windows (Git Bash) 版刷写脚本 —— 适配 ESP32-S3-N16R8（16MB Flash + 8MB OPI PSRAM）
# 用法: hardware/flash-win.sh [COM口] [--debug] [--build-only]
#   --debug      在 USB 串口打印命令和 AirPlay 握手日志
#   --build-only 只编译（打印固件大小）
#
# 与官方 flash.sh 的差异：
#   1) FQBN 改为 FlashSize=16M + 16MB 分区表（N16R8 规格）
#   2) 串口是 COMx；进入下载模式交给 esptool 自动处理，失败时按住板子 BOOT 键再插一次
#   3) 路径含中文/非 ASCII 时，自动切到纯 ASCII 目录（默认 C:/Users/admin/esp32-build）构建，
#      因为 GCC 链接器 ld 无法在中文路径下写出 .elf（会报乱码路径 No such file or directory）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORIG_DIR="$SCRIPT_DIR"

# arduino-cli 路径：优先 ARDUINO_CLI 环境变量
CLI="${ARDUINO_CLI:-C:/Users/admin/tools/arduino-cli/arduino-cli.exe}"
[ -f "$CLI" ] || { echo "找不到 arduino-cli: $CLI（可用 ARDUINO_CLI 环境变量指定）"; exit 1; }

FQBN="esp32:esp32:esp32s3:USBMode=default,CDCOnBoot=cdc,FlashSize=16M,PSRAM=opi,PartitionScheme=app3M_fat9M_16MB"

PORT="" DEFS="" BUILD_ONLY=0
for a in "$@"; do
  case $a in
    --debug)      DEFS+=" -DDEBUG_SERIAL=1" ;;
    --build-only) BUILD_ONLY=1 ;;
    *)            PORT=$a ;;
  esac
done

# 路径含非 ASCII（如「开发板」）时改用 ASCII 构建目录
ASCII_DIR="$SCRIPT_DIR"
if printf '%s' "$SCRIPT_DIR" | LC_ALL=C grep -q '[^ -~]'; then
  MIRROR="${ESP32_BUILD_DIR:-C:/Users/admin/esp32-build}"
  echo ">> 路径含非 ASCII 字符，改用 ASCII 构建目录: $MIRROR"
  mkdir -p "$MIRROR"
  cp -ru "$SCRIPT_DIR/hid_bridge" "$MIRROR/"
  ASCII_DIR="$MIRROR"
fi

cd "$ASCII_DIR"
WINDIR="$(pwd -W 2>/dev/null || pwd)"
case "$WINDIR" in *" "*) echo "构建路径不能包含空格: $WINDIR"; exit 1;; esac
DEFS+=" -include $WINDIR/hid_bridge/nimble_cfg.h"
FLAGS=(--build-property "compiler.cpp.extra_flags=$DEFS" --build-property "compiler.c.extra_flags=$DEFS")

echo ">> 编译（构建目录 $WINDIR）..."
MSYS2_ARG_CONV_EXCL='*' "$CLI" compile -b "$FQBN" "${FLAGS[@]}" \
  --build-path "$WINDIR/build-cache" --output-dir "$WINDIR/build" hid_bridge
(( BUILD_ONLY )) && exit 0

# 产物拷回原目录，方便查看与上传
if [[ "$ASCII_DIR" != "$ORIG_DIR" ]]; then
  mkdir -p "$ORIG_DIR/build"
  cp -f "$ASCII_DIR"/build/*.bin "$ORIG_DIR/build/" 2>/dev/null || true
  cp -f "$ASCII_DIR"/build/*.elf "$ORIG_DIR/build/" 2>/dev/null || true
  echo ">> 产物已复制回 $ORIG_DIR/build/"
fi

PORT="${PORT:-COM3}"
echo ">> 上传到 $PORT ..."
MSYS2_ARG_CONV_EXCL='*' "$CLI" upload -b "$FQBN" -p "$PORT" --input-dir "$WINDIR/build" hid_bridge
echo "✅ 刷写完成 → $PORT"
echo "   （若上传失败：按住板子 BOOT 键插 USB 后重跑本脚本）"
