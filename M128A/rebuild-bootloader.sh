#!/usr/bin/env bash
# Recompila el bootloader Optiboot para ATmega128/A 16 MHz / 57600 baud / UART0 / LED PC6.
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
     "$UPSTREAM"/boot_opt.h "$UPSTREAM"/link_optiboot.ld "$UPSTREAM"/baudcheck.c "$SRC/" 2>/dev/null || true
  cp "$UPSTREAM/Makefile" "$SRC/Makefile.optiboot.original"
  cp "$UPSTREAM/Makefile.mcudude" "$SRC/Makefile.mcudude.original"
fi

# El objetivo atmega128 vive en Makefile.mcudude (targets de MCUdude/MegaCore).
# Se compila en un dir temporal para no ensuciar las fuentes guardadas.
cp "$SRC"/optiboot.c "$SRC"/pin_defs.h "$SRC"/stk500.h "$SRC"/boot_opt.h \
   "$SRC"/link_optiboot.ld "$SRC"/baudcheck.c "$BUILD_DIR/" 2>/dev/null || true
cp "$SRC/Makefile.optiboot.original" "$BUILD_DIR/Makefile"
cp "$SRC/Makefile.mcudude.original" "$BUILD_DIR/Makefile.mcudude"

make -C "$BUILD_DIR" atmega128 UART=0 AVR_FREQ=16000000L BAUD_RATE=57600 LED=C6

cp "$BUILD_DIR/optiboot_atmega128_UART0_57600_16000000L.hex" \
   "$SCRIPT_DIR/bootloader/optiboot_atmega128_16M_57600_UART0_LED_C6.hex"
echo "OK -> bootloader/optiboot_atmega128_16M_57600_UART0_LED_C6.hex"
avr-size "$BUILD_DIR/optiboot_atmega128_UART0_57600_16000000L.elf"
echo "Debe ser <= 1024 bytes para caber en la seccion de boot (hfuse 0xDE = 512 words)."
