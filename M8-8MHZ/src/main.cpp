#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>

// Prueba: parpadea LED en PB2 (ACTIVO EN BAJO: enciende con 0)
// y envía un contador por UART a 9600 8N1.
// UART: TXD = PD1, RXD = PD0. F_CPU = 8 MHz RC interno (platformio.ini).

#define BAUD 9600
#define UBRR_VAL ((F_CPU / 16UL / BAUD) - 1UL)

static void uart_init(void) {
  UBRRH = (uint8_t)(UBRR_VAL >> 8);
  UBRRL = (uint8_t)UBRR_VAL;
  UCSRA = 0;                                     // modo normal (U2X = 0)
  UCSRB = (1 << RXEN) | (1 << TXEN);             // habilita RX y TX
  // OJO ATmega8: UCSRC comparte dirección con UBRRH, URSEL = 1 selecciona UCSRC
  UCSRC = (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0);  // 8 bits, sin paridad, 1 stop
}

static void uart_putc(char c) {
  if (c == '\n') uart_putc('\r');
  while (!(UCSRA & (1 << UDRE))) { /* espera */ }
  UDR = c;
}

static void uart_puts(const char *s) {
  while (*s) uart_putc(*s++);
}

static void uart_putu32(uint32_t v) {
  char buf[11];
  uint8_t i = 0;
  if (v == 0) { uart_putc('0'); return; }
  while (v > 0 && i < sizeof(buf)) { buf[i++] = (char)('0' + v % 10); v /= 10; }
  while (i--) uart_putc(buf[i]);
}

int main(void) {
  uint32_t contador = 0;
  DDRB |= (1 << DDB2);   // PB2 como salida (LED activo en bajo)

  uart_init();
  uart_puts("M8-8MHZ listo. Contador por UART a 9600:\n");

  while (1) {
    PORTB &= ~(1 << PORTB2);  // LED ON (nivel bajo)
    uart_puts("Contador: ");
    uart_putu32(contador++);
    uart_putc('\n');
    _delay_ms(500);
    PORTB |= (1 << PORTB2);   // LED OFF (nivel alto)
    _delay_ms(500);
  }
  return 0;
}
