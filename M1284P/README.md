# AVRBOOT/M1284P — Bootloader serie para ATmega1284/P + PlatformIO

Bootloader **Optiboot** compilado para:

| Parámetro | Valor |
|---|---|
| MCU | ATmega1284 / ATmega1284P |
| Reloj | Cristal externo **7.3728 MHz** (+ 2×22 pF) |
| UART bootloader | **UART0** (RXD0 = PD0, TXD0 = PD1) |
| Baud bootloader | **115200** (error **0.00 %**: 7.3728 MHz = 115200 × 64) |
| LED boot | PB0, activo en alto (3 parpadeos al reset, apagado al saltar a la app) |
| Tamaño | 789 / 1024 bytes (sección boot en `0x1FC00`, BIGBOOT) |
| Protocolo subida | STK500v1 (`upload_protocol = arduino`) |

> El cristal de 7.3728 MHz es "mágico" para serie: 115200, 57600, 38400 y 9600
> salen con error 0.00 %. Se eligió 115200 para subir rápido los 128 KB.

Hex listo: `bootloader/optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex`
Fuentes: `bootloader/optiboot_src/` (el objetivo `atmega1284p` vive en
`Makefile.1284.original`).

## 1. Conexiones

### 1a. Grabación inicial (USBasp → ICSP, solo 1 vez)
```
USBasp MOSI  -> PB5/MOSI (pin 6)
USBasp MISO  -> PB6/MISO (pin 7)
USBasp SCK   -> PB7/SCK  (pin 8)
USBasp RST   -> RESET     (pin 9)
USBasp VCC   -> VCC, GND -> GND
```
Cristal de 7.3728 MHz entre XTAL1 (pin 12) y XTAL2 (pin 13) + 2×22 pF a GND.

### 1b. Uso normal (USB-Serie → UART0, pines PDIP40)
```
USB-TTL TX  -> PD0/RXD0 (pin 14)
USB-TTL RX  -> PD1/TXD0 (pin 15)
USB-TTL DTR -> 100nF -> RESET (pin 9) + pull-up 10k a VCC
GND común
```
Referencia PDIP40: PB0 (LED) = pin 1; ICSP: PB5/MOSI = 6, PB6/MISO = 7,
PB7/SCK = 8, RESET = 9; cristal XTAL1/XTAL2 = pines 12/13.

## 2. Grabar bootloader + fuses (USBasp)

```bash
cd M1284P
pio run -e burn_bootloader -t fuses
pio run -e burn_bootloader -t bootloader
```

O directo con avrdude:
```bash
avrdude -c usbasp -p m1284p -U lfuse:w:0xF7:m -U hfuse:w:0xDE:m -U efuse:w:0xFD:m
avrdude -c usbasp -p m1284p -D \
  -U flash:w:bootloader/optiboot_atmega1284p_7M3728_115200_UART0_LED_B0.hex:i \
  -U lock:w:0x0F:m
```

Fuses programados:

| Fuse | Valor | Significado |
|---|---|---|
| LOW | `0xF7` | Cristal externo, arranque 16K CK + 65 ms |
| HIGH | `0xDE` | BOOTRST activado, boot de 512 words / 1024 B (`0x1FC00`), SPI habilitado, JTAG deshabilitado (libera PORTC) |
| EXT | `0xFD` | BOD a 2.7 V |
| LOCK | `0x3F`→`0x0F` | Sin bloqueo de app, sección boot protegida |

Verifica con:
```bash
avrdude -c usbasp -p m1284p -U lfuse:r:-:h -U hfuse:r:-:h -U efuse:r:-:h
# esperado: lfuse 0xf7, hfuse 0xde, efuse 0xfd
```

## 3. Subir programas por serie

1. Desconecta USBasp, conecta el conversor USB-Serie a UART0.
2. Ajusta `upload_port` en `platformio.ini` (`/dev/ttyUSB0`, `/dev/ttyACM0` o `COM3`).
3. Compila y sube:
```bash
pio run -e app -t upload
pio device monitor -e app   # 9600 baud, ver "Contador: N"
```

O directo con avrdude (la app compilada está en `.pio/build/app/firmware.hex`):
```bash
avrdude -c arduino -P /dev/ttyUSB0 -b 115200 -p m1284p -U flash:w:.pio/build/app/firmware.hex:i
```

Desglose de parámetros:

| Parámetro | Significado |
|---|---|
| `-c arduino` | Protocolo STK500v1 que habla Optiboot |
| `-P /dev/ttyUSB0` | Puerto del conversor USB-serie (en Windows: `COM3`) |
| `-b 115200` | Baud del bootloader (debe coincidir con el compilado) |
| `-p m1284p` | Micro destino (firma esperada `1E 97 05`) |
| `-U flash:w:...:i` | Escribe la app en formato Intel HEX |

Ejemplo de sesión completa (compilar + subir + monitorear):
```bash
cd M1284P
pio run -e app                                   # compila -> .pio/build/app/firmware.hex
avrdude -c arduino -P /dev/ttyUSB0 -b 115200 -p m1284p \
  -U flash:w:.pio/build/app/firmware.hex:i
# esperado:
# Device signature = 0x1e9705
# Writing | ################################################## | 100%
# Reading | ################################################## | 100%
# avrdude: 123 bytes of flash verified
pio device monitor -e app                        # 9600 baud, ver "Contador: N"
```

> Si avrdude protesta por la firma pero por USBasp sale bien, es ruido en la
> línea RX: agrega `-F` (la escritura queda bien igual; verifícala por USBasp).
> Ver proyecto M128A para el detalle.

> Al pulsar RESET el LED (PB0) parpadea 3 veces: es Optiboot esperando
> 1 s un upload a 115200 baud. Si no llega nada, salta a tu programa.
> El programa de prueba (`src/main.cpp`) parpadea el LED de PB0 a 1 Hz
> y manda un contador por UART0 a 9600 (también exacto a 7.3728 MHz).

## 4. Recompilar el bootloader (opcional)

```bash
bash rebuild-bootloader.sh
```

Equivale a:
```bash
make atmega1284p UART=0 AVR_FREQ=7372800L BAUD_RATE=115200 LED=B0
```

> Nota: cada recompilación incrusta fecha/hora (`Built:...`) en el binario
> (típico de builds BIGBOOT), así que el `.hex` nunca será byte-idéntico entre
> compilaciones aunque el código sea el mismo.

## 5. Problemas comunes

- `stk500_recv(): programmer is not responding` → puerto equivocado, UART equivocada
  (debe ser UART0: PD0/PD1), sin auto-reset (falta el condensador DTR-RESET),
  o bootloader no grabado.
- `avrdude: usbasp not found` → permisos udev en Linux: añade tu usuario a
  `dialout`/`uucp`, o usa `sudo`. Clones lentos: descomenta
  `upload_flags = -Pusb -B 10` en `env:burn_bootloader`.
- El puerto PORTC no responde → JTAG está activado; graba hfuse `0xDE`
  (JTAG deshabilitado).
- Firma esperada ATmega1284P: `1E 97 05`. Si por serie sale corrupta en un bit
  pero por USBasp sale bien, es ruido en la línea RX (ver proyecto M128A).
