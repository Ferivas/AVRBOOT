#!/usr/bin/env bash
# Recompila el bootloader Optiboot para ATmega328P 16 MHz / 57600 baud / LED PB5.
# Requiere: toolchain-atmelavr de PlatformIO (o avr-gcc en PATH).
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(mktemp -d)"
TOOLCHAIN="$HOME/.platformio/packages/toolchain-atmelavr/bin"

if [ -d "$TOOLCHAIN" ]; then
  export PATH="$TOOLCHAIN:$PATH"
fi

command -v avr-gcc >/dev/null || { echo "ERROR: avr-gcc no encontrado. Instala toolchain-atmelavr."; exit 1; }

if [ ! -f "$SCRIPT_DIR/bootloader/optiboot_src/optiboot.c" ]; then
  echo "Descargando fuentes Optiboot..."
  mkdir -p "$SCRIPT_DIR/bootloader/optiboot_src"
  git clone --depth 1 https://github.com/Optiboot/optiboot.git "$BUILD_DIR/optiboot"
  cp "$BUILD_DIR/optiboot/optiboot/bootloaders/optiboot/"*.{c,h,ld,Makefile} "$SCRIPT_DIR/bootloader/optiboot_src/" 2>/dev/null || true
  SRC="$BUILD_DIR/optiboot/optiboot/bootloaders/optiboot"
else
  SRC="$SCRIPT_DIR/bootloader/optiboot_src"
  echo "Usando fuentes en bootloader/optiboot_src"
fi

cd "$SRC"
make atmega328 AVR_FREQ=16000000L BAUD_RATE=57600 LED=B5

cp optiboot_atmega328.hex "$SCRIPT_DIR/bootloader/optiboot_atmega328_16M_57600.hex"
echo "OK -> bootloader/optiboot_atmega328_16M_57600.hex"
avr-size optiboot_atmega328.elf
echo "Debe ser <= 512 bytes para caber en la seccion de boot."
