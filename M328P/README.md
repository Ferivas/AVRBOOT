# AVRBOOT — Bootloader serie para ATmega328P + PlatformIO

Bootloader **Optiboot** (el mismo de Arduino UNO) compilado para:

| Parámetro | Valor |
|---|---|
| MCU | ATmega328P |
| Reloj | Cristal externo **16 MHz** |
| Baud bootloader | **57600** (error 0.7 %, estable) |
| LED boot | PB5 (pin 13 Arduino, 3 parpadeos al reset) |
| Tamaño | 498 / 512 bytes |
| Protocolo subida | STK500v1 (`upload_protocol = arduino`) |

Hex listo: `bootloader/optiboot_atmega328_16M_57600.hex`

## 1. Conexiones

### 1a. Grabación inicial (USBasp → ICSP, solo 1 vez)
```
USBasp MOSI  -> PB3 (pin 17)
USBasp MISO  -> PB4 (pin 18)
USBasp SCK   -> PB5 (pin 19)
USBasp RST   -> PC6/RESET (pin 1)
USBasp VCC   -> VCC, GND -> GND
```
El ATmega debe estar alimentado y con cristal de 16 MHz + 2×22 pF.

### 1b. Uso normal (USB-Serie → UART)
```
USB-TTL TX  -> PD0/RX (pin 2)
USB-TTL RX  -> PD1/TX (pin 3)
USB-TTL DTR -> 100nF -> RESET (pin 1) + pull-up 10k a VCC
GND común
```

## 2. Grabar bootloader + fuses (USBasp)

```bash
# Ajusta upload_port en platformio.ini si es necesario (solo para env:app).
# Paso 1: fuses, Paso 2: bootloader
pio run -e burn_bootloader -t fuses
pio run -e burn_bootloader -t bootloader
```

Fuses programados:

| Fuse | Valor | Significado |
|---|---|---|
| LOW | `0xFF` | Cristal externo alta frecuencia, arranque rápido |
| HIGH | `0xDE` | BOOTRST activado, boot de 512 B (0x7E00), SPI habilitado |
| EXT | `0xFD` | BOD a 2.7 V |
| LOCK | `0xFF`→`0xCF` | Sin bloqueo de app, sección boot protegida |

Verifica con:
```bash
avrdude -c usbasp -p m328p -U lfuse:r:-:h -U hfuse:r:-:h -U efuse:r:-:h
# esperado: lfuse 0xff, hfuse 0xde, efuse 0xfd
```

## 3. Subir programas por serie

1. Desconecta USBasp, conecta el conversor USB-Serie.
2. Ajusta `upload_port` en `platformio.ini` (`/dev/ttyUSB0`, `/dev/ttyACM0` o `COM3`).
3. Compila y sube:
```bash
pio run -e app -t upload
pio device monitor -e app   # 9600 baud, ver "LED ON/OFF"
```

> Al pulsar RESET el LED (PB5) parpadea 3 veces: es Optiboot esperando
> 1 s un upload a 57600 baud. Si no llega nada, salta a tu programa.

## 4. Recompilar el bootloader (opcional)

```bash
bash rebuild-bootloader.sh
```

Equivale a:
```bash
make atmega328 AVR_FREQ=16000000L BAUD_RATE=57600 LED=B5
```

## 5. Problemas comunes

- `stk500_recv(): programmer is not responding` → puerto equivocado, sin auto-reset (falta el condensador DTR-RESET), o bootloader no grabado.
- `avrdude: usbasp not found` → permisos udev en Linux: añade tu usuario a `dialout`/`uucp`, o usa `sudo`. Clones lentos: descomenta `upload_flags = -Pusb -B 10` en `env:burn_bootloader`.
- 8 MHz interno en vez de 16 MHz → recompila con `AVR_FREQ=8000000L` y baud 38400 o 57600 (revisa `baudcheck`), y cambia fuses LOW a `0xE2`.
