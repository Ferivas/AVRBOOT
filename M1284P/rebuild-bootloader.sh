#!/usr/bin/env bash
# Recompila el bootloader Optiboot para ATmega1284P 7.3728 MHz / 115200 baud / UART0 / LED PB0.
# Requiere: toolchain-atmelavr de PlatformIO (o avr-gcc + make en PATH).
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(mktemp -d)"
TOOLCHAIN="$HOME/.platformio/packages/toolchain-atmelavr/bin"

if [ -d "$TOOLCHAIN" ]; then
  export PATH="$TOOLCHAIN:$PATH"
fi

command -v avr-gcc >/dev/null || { echo "ERROR: avr-gcc no encontrado. Instala toolchain-atmelavr."; exit 1; }
command -v make >/dev/null || { echo "ERROR: make no encontrado."; exit 1; }

SRC="$SCRIPT_DIR/bootloader/optiboot_src"
if [ ! -f "$SRC/optiboot.c" ] || [ ! -f "$SRC/Makefile.optiboot.original" ]; then
  echo "Descargando fuentes Optiboot..."
  mkdir -p "$SRC"
  git clone --depth 1 https://github.com/Optiboot/optiboot.git "$BUILD_DIR/optiboot"
  UPSTREAM="$BUILD_DIR/optiboot/optiboot/bootloaders/optiboot"
  cp "$UPSTREAM"/optiboot.c "$UPSTREAM"/pin_defs.h "$UPSTREAM"/stk500.h \
     "$UPSTREAM"/boot_opt.h "$UPSTREAM"/link_optiboot.ld "$SRC/" 2>/dev/null || true
  cp "$UPSTREAM/Makefile" "$SRC/Makefile.optiboot.original"
  cp "$UPSTREAM/Makefile.1284" "$SRC/Makefile.1284.original"
  cp "$UPSTREAM/Makefile.mcudude" "$SRC/Makefile.mcudude.original"
fi

# El objetivo atmega1284p vive en Makefile.1284.
# Se compila en un dir temporal para no ensuciar las fuentes guardadas.
cp "$SRC"/optiboot.c "$SRC"/pin_defs.h "$SRC"/stk500.h "$SRC"/boot_opt.h \
   "$SRC"/link_optiboot.ld "$BUILD_DIR/"
cp "$SRC/Makefile.optiboot.original" "$BUILD_DIR/Makefile"
cp "$SRC/Makefile.1284.original" "$BUILD_DIR/Makefile.1284" 2>/dev/null || true
cp "$SRC/Makefile.mcudude.original" "$BUILD_DIR/Makefile.mcudude" 2>/dev/null || true

make -C "$BUILD_DIR" atmega1284p UART=0 AVR_FREQ=7372800L BAUD_RATE=115200 LED=B0

cp "$BUILD_DIR/optiboot_atmega1284p.hex" \
   "$SCRIPT_DIR/bootloader/optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex"
echo "OK -> bootloader/optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex"
avr-size "$BUILD_DIR/optiboot_atmega1284p.elf"
echo "Debe ser <= 1024 bytes (seccion de boot en 0x1FC00, hfuse 0xDE = BOOTSZ 512 words)."
