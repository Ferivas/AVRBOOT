#!/usr/bin/env bash
# Recompila el bootloader Optiboot para ATmega8 8 MHz RC interno / 38400 baud / LED PB2 activo en bajo.
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
  echo "NOTA: este proyecto usa un parche LED_INVERT en optiboot.c (LED activo en bajo)."
  echo "Si descargaste fuentes nuevas, reaplícalo antes de compilar."
fi

# Se compila en un dir temporal para no ensuciar las fuentes guardadas.
# (El Makefile principal incluye otros Makefile.* que no guardamos; se ignoran esos avisos.)
cp "$SRC"/optiboot.c "$SRC"/pin_defs.h "$SRC"/stk500.h "$SRC"/boot_opt.h \
   "$SRC"/link_optiboot.ld "$BUILD_DIR/"
cp "$SRC/Makefile.optiboot.original" "$BUILD_DIR/Makefile"

# LED_INVERT=1: LED de PB2 activo en bajo (se enciende con 0).
make -C "$BUILD_DIR" atmega8 AVR_FREQ=8000000L BAUD_RATE=38400 LED=B2 'EXTRA_CFLAGS=-DLED_INVERT=1'

cp "$BUILD_DIR/optiboot_atmega8.hex" \
   "$SCRIPT_DIR/bootloader/optiboot_atmega8_8M_38400_LED_B2inv.hex"
echo "OK -> bootloader/optiboot_atmega8_8M_38400_LED_B2inv.hex"
avr-size "$BUILD_DIR/optiboot_atmega8.elf"
echo "Debe ser <= 512 bytes (seccion de boot en 0x1E00, hfuse 0xDC = BOOTSZ=10, 256 words)."
