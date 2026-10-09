# AVRBOOT/M128A — Bootloader serie para ATmega128/A + PlatformIO

Bootloader **Optiboot** compilado para:

| Parámetro | Valor |
|---|---|
| MCU | ATmega128 / ATmega128A |
| Reloj | Cristal externo **16 MHz** |
| UART bootloader | **UART0** (RXD0 = PE0, TXD0 = PE1) |
| Baud bootloader | **57600** (error 0.7 %, estable) |
| LED boot | PC6 (3 parpadeos al reset) |
| Tamaño | 787 / 1024 bytes |
| Protocolo subida | STK500v1 (`upload_protocol = arduino`) |

Hex listo: `bootloader/optiboot_atmega128_16M_57600_UART0_LED_C6.hex`
Fuentes: `bootloader/optiboot_src/` (+ `Makefile.mcudude.original`, donde vive el objetivo `atmega128`).

## 1. Conexiones

### 1a. Grabación inicial (USBasp → ICSP, solo 1 vez)
```
USBasp MOSI  -> PB2/MOSI
USBasp MISO  -> PB3/MISO
USBasp SCK   -> PB1/SCK
USBasp RST   -> RESET
USBasp VCC   -> VCC, GND -> GND
```
El ATmega debe estar alimentado y con cristal de 16 MHz + 2×22 pF.

### 1b. Uso normal (USB-Serie → UART0)
```
USB-TTL TX  -> PE0/RXD0 (pin 2)
USB-TTL RX  -> PE1/TXD0 (pin 3)
USB-TTL DTR -> 100nF -> RESET + pull-up 10k a VCC
GND común
```

## 2. Grabar bootloader + fuses (USBasp)

```bash
cd M128A
pio run -e burn_bootloader -t fuses
pio run -e burn_bootloader -t bootloader
```

Fuses programados:

| Fuse | Valor | Significado |
|---|---|---|
| LOW | `0xFF` | Cristal externo alta frecuencia, arranque lento (16K CK + 65 ms) |
| HIGH | `0xDE` | BOOTRST activado, boot de 512 words / 1024 B (0x1FC00), SPI habilitado, JTAG deshabilitado (libera PORTF) |
| EXT | `0xFF` | Modo ATmega128 nativo (M103C = 1), BOD deshabilitado |
| LOCK | `0x3F`→`0x0F` | Sin bloqueo de app, sección boot protegida |

> Para activar el BOD, usa efuse `0xFE` (BOD activado). Ojo: en el ATmega128 el nivel
> es ~4.0 V (no 2.7 V); no lo actives si alimentas a 3.3 V.
> Si el cristal de 16 MHz no arranca de forma fiable, prueba hfuse `0xCE`
> (CKOPT = 0, oscilador full-swing).

Verifica con:
```bash
avrdude -c usbasp -p m128 -U lfuse:r:-:h -U hfuse:r:-:h -U efuse:r:-:h
# esperado: lfuse 0xff, hfuse 0xde, efuse 0xff
```

## 3. Subir programas por serie

1. Desconecta USBasp, conecta el conversor USB-Serie a UART0.
2. Ajusta `upload_port` en `platformio.ini` (`/dev/ttyUSB0`, `/dev/ttyACM0` o `COM3`).
3. Compila y sube:
```bash
pio run -e app -t upload
pio device monitor -e app   # 9600 baud
```

> Al pulsar RESET el LED (PC6) parpadea 3 veces: es Optiboot esperando
> 1 s un upload a 57600 baud. Si no llega nada, salta a tu programa.
> El programa de prueba (`src/main.cpp`) parpadea el LED de PC6 a 1 Hz.

## 4. Recompilar el bootloader (opcional)

```bash
bash rebuild-bootloader.sh
```

Equivale a:
```bash
make atmega128 UART=0 AVR_FREQ=16000000L BAUD_RATE=57600 LED=C6
```
El objetivo `atmega128` viene de `Makefile.mcudude` (targets de MCUdude/MegaCore);
el script lo usa automáticamente desde las fuentes guardadas en `bootloader/optiboot_src/`.

## 5. Problemas comunes

- `stk500_recv(): programmer is not responding` → puerto equivocado, UART equivocada
  (debe ser UART0: PE0/PE1), sin auto-reset (falta el condensador DTR-RESET), o bootloader no grabado.
- `avrdude: usbasp not found` → permisos udev en Linux: añade tu usuario a `dialout`/`uucp`,
  o usa `sudo`. Clones lentos: descomenta `upload_flags = -Pusb -B 10` en `env:burn_bootloader`.
- El puerto PORTF no responde → JTAG está activado; graba hfuse `0xDE` (JTAGEN = 1, deshabilitado).
- Solo funciona como ATmega103 → se programó M103C; graba efuse `0xFF` (modo ATmega128 nativo).
