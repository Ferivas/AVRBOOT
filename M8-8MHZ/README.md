# AVRBOOT/M8-8MHZ — Bootloader serie para ATmega8/A + PlatformIO

Bootloader **Optiboot** compilado para:

| Parámetro | Valor |
|---|---|
| MCU | ATmega8 / ATmega8A |
| Reloj | Oscilador RC interno calibrado a **8 MHz** (sin cristal) |
| UART bootloader | RXD = PD0, TXD = PD1 |
| Baud bootloader | **38400** (error 0.16 %, seguro con la deriva del RC) |
| LED boot | PB2, **activo en bajo** (3 parpadeos al reset, apagado al saltar a la app) |
| Tamaño | 476 / 512 bytes (sección boot en `0x1E00`) |
| Protocolo subida | STK500v1 (`upload_protocol = arduino`) |

Hex listo: `bootloader/optiboot_atmega8_8M_38400_LED_B2inv.hex`
Fuentes: `bootloader/optiboot_src/` + **parche `LED_INVERT`** en `optiboot.c`
(Optiboot asume LED activo en alto; el parche invierte init y apagado final).

## 1. Conexiones

### 1a. Grabación inicial (USBasp → ICSP, solo 1 vez)
```
USBasp MOSI  -> PB3/MOSI (pin 16)
USBasp MISO  -> PB4/MISO (pin 17)
USBasp SCK   -> PB5/SCK  (pin 19)
USBasp RST   -> RESET     (pin 1)
USBasp VCC   -> VCC, GND -> GND
```
Operando con RC interno, **PB6/PB7 quedan libres** como GPIO. No conectes
cristal. Nota de errata: en ATmega8 anteriores a Rev. G, con RC interno se
recomiendan condensadores de 20-36 pF de XTAL1/XTAL2 a GND (sin cristal);
desde Rev. G los capacitores internos se activan solos.

### 1b. Uso normal (USB-Serie → UART)
```
USB-TTL TX  -> PD0/RXD (pin 2)
USB-TTL RX  -> PD1/TXD (pin 3)
USB-TTL DTR -> 100nF -> RESET (pin 1) + pull-up 10k a VCC
GND común
```

## 2. Grabar bootloader + fuses (USBasp)

```bash
cd M8-8MHZ
pio run -e burn_bootloader -t fuses
pio run -e burn_bootloader -t bootloader
```

O directo con avrdude:
```bash
avrdude -c usbasp -p m8 -U lfuse:w:0xC4:m -U hfuse:w:0xDC:m
avrdude -c usbasp -p m8 -D -U flash:w:bootloader/optiboot_atmega8_8M_38400_LED_B2inv.hex:i \
  -U lock:w:0x0F:m
```

Fuses programados:

| Fuse | Valor | Significado |
|---|---|---|
| LOW | `0xC4` | RC interno calibrado **8 MHz**, arranque SUT=00 (el de fábrica, el más largo), BOD off |
| HIGH | `0xDC` | BOOTRST activado, boot de 256 words / 512 B (`0x1E00`, BOOTSZ=10), SPI habilitado |
| LOCK | `0x3F`→`0x0F` | Sin bloqueo de app, sección boot protegida |

> El ATmega8 **no tiene byte efuse**: no aparece en la configuración (la plataforma
> ya lo omite sola). De fábrica el ATmega8 viene en `0xE1` (RC a **1 MHz**);
> si no reprogramas los fuses, el bootloader corre a 1 MHz y el baud no cuadra.

Verifica con:
```bash
avrdude -c usbasp -p m8 -U lfuse:r:-:h -U hfuse:r:-:h
# esperado: lfuse 0xc4, hfuse 0xdc
```

## 3. Subir programas por serie

1. Desconecta USBasp, conecta el conversor USB-Serie.
2. Ajusta `upload_port` en `platformio.ini` (`/dev/ttyUSB0`, `/dev/ttyACM0` o `COM3`).
3. Compila y sube:
```bash
pio run -e app -t upload
pio device monitor -e app   # 9600 baud, ver "Contador: N"
```

O directo con avrdude (la app compilada está en `.pio/build/app/firmware.hex`):
```bash
avrdude -c arduino -P /dev/ttyUSB0 -b 38400 -p m8 -U flash:w:.pio/build/app/firmware.hex:i
```

> Al pulsar RESET el LED (PB2) parpadea 3 veces: es Optiboot esperando
> 1 s un upload a 38400 baud. Si no llega nada, salta a tu programa.
> El programa de prueba (`src/main.cpp`) parpadea el LED de PB2 (activo en bajo)
> y manda un contador por UART a 9600.

## 4. Recompilar el bootloader (opcional)

```bash
bash rebuild-bootloader.sh
```

Equivale a:
```bash
make atmega8 AVR_FREQ=8000000L BAUD_RATE=38400 LED=B2 EXTRA_CFLAGS="-DLED_INVERT=1"
```

## 5. Notas de precisión del reloj

- El RC interno deriva con voltaje/temperatura (±1-3 % típico). A 38400 hay
  margen de sobra (0.16 % de error de cálculo); a 57600 el error total (~4 %)
  puede hacer fallar la sincronización: por eso se eligió 38400.
- Al reset, el hardware carga en `OSCCAL` la calibración de **1 MHz**; a 8 MHz
  la exactitud depende del trim de fábrica de cada chip (suele estar bien).
- Si un chip concreto da errores de sync, prueba bajar a 19200
  (`BAUD_RATE=19200` + `upload_speed = 19200`).

## 6. Problemas comunes

- `stk500_recv(): programmer is not responding` → puerto equivocado, sin auto-reset
  (falta el condensador DTR-RESET), fuses en 1 MHz de fábrica (revisa lfuse `0xC4`),
  o bootloader no grabado.
- `avrdude: usbasp not found` → permisos udev en Linux: añade tu usuario a
  `dialout`/`uucp`, o usa `sudo`. Clones lentos: descomenta
  `upload_flags = -Pusb -B 10` en `env:burn_bootloader`.
- Firma `1E 93 07` esperada para ATmega8: si avrdude la reporta corrupta en un
  solo bit por serie pero bien por USBasp, es ruido en la línea RX (ver proyecto M128A).
