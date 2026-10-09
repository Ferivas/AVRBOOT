#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>

// Prueba: parpadea LED en PB0 (ACTIVO EN ALTO: enciende con 1)
// y envía un contador por UART0 a 9600 8N1.
// UART0: TXD0 = PD1, RXD0 = PD0. F_CPU = 7.3728 MHz (platformio.ini).
// A 7.3728 MHz el baud 9600 es exacto (UBRR = 47, error 0 %).

#define BAUD 9600
#define UBRR_VAL ((F_CPU / 16UL / BAUD) - 1UL)

static void uart0_init(void) {
  UBRR0H = (uint8_t)(UBRR_VAL >> 8);
  UBRR0L = (uint8_t)UBRR_VAL;
  UCSR0A = 0;                                    // modo normal (U2X = 0)
  UCSR0B = (1 << RXEN0) | (1 << TXEN0);          // habilita RX y TX
  UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);        // 8 bits, sin paridad, 1 stop
  // Nota: en el ATmega1284P UCSR0C y UBRR0H tienen direcciones separadas,
  // no se necesita bit URSEL (ese solo existe en m8/m16/m32).
}

static void uart0_putc(char c) {
  if (c == '\n') uart0_putc('\r');
  while (!(UCSR0A & (1 << UDRE0))) { /* espera */ }
  UDR0 = c;
}

static void uart0_puts(const char *s) {
  while (*s) uart0_putc(*s++);
}

static void uart0_putu32(uint32_t v) {
  char buf[11];
  uint8_t i = 0;
  if (v == 0) { uart0_putc('0'); return; }
  while (v > 0 && i < sizeof(buf)) { buf[i++] = (char)('0' + v % 10); v /= 10; }
  while (i--) uart0_putc(buf[i]);
}

int main(void) {
  uint32_t contador = 0;
  DDRB |= (1 << DDB0);   // PB0 como salida (LED activo en alto)

  uart0_init();
  uart0_puts("M1284P listo. Contador por UART0 a 9600:\n");

  while (1) {
    PORTB |= (1 << PORTB0);   // LED ON (nivel alto)
    uart0_puts("Contador: ");
    uart0_putu32(contador++);
    uart0_putc('\n');
    _delay_ms(500);
    PORTB &= ~(1 << PORTB0);  // LED OFF (nivel bajo)
    _delay_ms(500);
  }
  return 0;
}
