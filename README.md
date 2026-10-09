# AVRBOOT — Bootloaders serie Optiboot (PlatformIO + avrdude + USBASP)

Un proyecto PlatformIO por microcontrolador, cada uno con su bootloader
Optiboot compilado, programa de prueba y scripts de recompilación.

| Carpeta | MCU | Reloj | Baud boot | LED boot | Hex del bootloader |
|---|---|---|---|---|---|
| `M328P/` | ATmega328P | Cristal ext. 16 MHz | 57600 | PB5 (alto) | `optiboot_atmega328_16M_57600.hex` |
| `M128A/` | ATmega128/A | Cristal ext. 16 MHz | 57600 (UART0) | PC6 (alto) | `optiboot_atmega128_16M_57600_UART0_LED_C6.hex` |
| `M8-8MHZ/` | ATmega8/A | RC interno 8 MHz | 38400 | PB2 (**bajo**) | `optiboot_atmega8_8M_38400_LED_B2inv.hex` |
| `M1284P/` | ATmega1284/P | Cristal 7.3728 MHz | 115200 (UART0) | PB0 (alto) | `optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex` |

Flujo general por carpeta: **1)** grabar fuses + bootloader una sola vez con
USBASP → **2)** subir programas por puerto serie con el bootloader.

> En los comandos avrdude ajusta `-B 10` (o mayor) si tu USBASP es un clon lento,
> y `/dev/ttyUSB0` por tu puerto (`COM3` en Windows, `/dev/ttyACM0` en Linux).

---

## M328P — ATmega328P, 16 MHz, 57600, LED PB5

Fuses: `lfuse 0xFF`, `hfuse 0xDE`, `efuse 0xFD`, `lock 0x3F→0x0F`.

```bash
cd M328P
# 1. Bootloader + fuses con USBASP (una sola vez)
pio run -e burn_bootloader -t fuses -t bootloader
# o directo con avrdude:
avrdude -c usbasp -p m328p -U lfuse:w:0xFF:m -U hfuse:w:0xDE:m -U efuse:w:0xFD:m
avrdude -c usbasp -p m328p -D -U flash:w:bootloader/optiboot_atmega328_16M_57600.hex:i -U lock:w:0x0F:m

# 2. Programa de ejemplo por serie (PD0/PD1 + DTR→100nF→RESET)
pio run -e app -t upload
# o directo con avrdude:
avrdude -c arduino -P /dev/ttyUSB0 -b 57600 -p m328p -U flash:w:.pio/build/app/firmware.hex:i
pio device monitor -e app   # 9600 baud
```

## M128A — ATmega128/A, 16 MHz, 57600 UART0, LED PC6

Fuses: `lfuse 0xFF`, `hfuse 0xDE`, `efuse 0xFF`, `lock 0x3F→0x0F`.

```bash
cd M128A
# 1. Bootloader + fuses con USBASP (una sola vez)
pio run -e burn_bootloader -t fuses -t bootloader
# o directo con avrdude:
avrdude -c usbasp -p m128 -U lfuse:w:0xFF:m -U hfuse:w:0xDE:m -U efuse:w:0xFF:m
avrdude -c usbasp -p m128 -D -U flash:w:bootloader/optiboot_atmega128_16M_57600_UART0_LED_C6.hex:i -U lock:w:0x0F:m

# 2. Programa de ejemplo por serie (UART0: PE0/PE1 + DTR→100nF→RESET)
pio run -e app -t upload
# o directo con avrdude:
avrdude -c arduino -P /dev/ttyUSB0 -b 57600 -p m128 -U flash:w:.pio/build/app/firmware.hex:i
pio device monitor -e app   # 9600 baud
```

## M8-8MHZ — ATmega8/A, RC interno 8 MHz, 38400, LED PB2 activo en bajo

Fuses: `lfuse 0xC4`, `hfuse 0xDC`, `lock 0x3F→0x0F` (sin byte efuse en el m8).

```bash
cd M8-8MHZ
# 1. Bootloader + fuses con USBASP (una sola vez)
pio run -e burn_bootloader -t fuses -t bootloader
# o directo con avrdude:
avrdude -c usbasp -p m8 -U lfuse:w:0xC4:m -U hfuse:w:0xDC:m
avrdude -c usbasp -p m8 -D -U flash:w:bootloader/optiboot_atmega8_8M_38400_LED_B2inv.hex:i -U lock:w:0x0F:m

# 2. Programa de ejemplo por serie (PD0/PD1 + DTR→100nF→RESET)
pio run -e app -t upload
# o directo con avrdude:
avrdude -c arduino -P /dev/ttyUSB0 -b 38400 -p m8 -U flash:w:.pio/build/app/firmware.hex:i
pio device monitor -e app   # 9600 baud
```

## M1284P — ATmega1284/P, 7.3728 MHz, 115200 UART0, LED PB0

Fuses: `lfuse 0xF7`, `hfuse 0xDE`, `efuse 0xFD`, `lock 0x3F→0x0F`.

```bash
cd M1284P
# 1. Bootloader + fuses con USBASP (una sola vez)
pio run -e burn_bootloader -t fuses -t bootloader
# o directo con avrdude:
avrdude -c usbasp -p m1284p -U lfuse:w:0xF7:m -U hfuse:w:0xDE:m -U efuse:w:0xFD:m
avrdude -c usbasp -p m1284p -D -U flash:w:bootloader/optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex:i -U lock:w:0x0F:m

# 2. Programa de ejemplo por serie (UART0: PD0/PD1, pines 14/15 + DTR→100nF→RESET)
pio run -e app -t upload
# o directo con avrdude:
avrdude -c arduino -P /dev/ttyUSB0 -b 115200 -p m1284p -U flash:w:.pio/build/app/firmware.hex:i
pio device monitor -e app   # 9600 baud
```

---

## Notas comunes

- Al pulsar RESET el LED de cada placa parpadea 3 veces: es Optiboot esperando
  1 s un upload a su baud. Si no llega nada, salta al programa.
- Cada carpeta tiene su propio `README.md` con cableado detallado, verificación
  de fuses y solución de problemas; además de `rebuild-bootloader.sh` para
  recompilar su bootloader desde las fuentes guardadas en `bootloader/optiboot_src/`.
- Si avrdude por serie protesta por la firma pero por USBASP sale bien, es ruido
  en la línea RX: agrega `-F` (ver caso documentado en `M128A/`).
