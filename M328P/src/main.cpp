#include <avr/io.h>
#include <util/delay.h>

// Prueba minima bare-metal: parpadea LED en PB5 (pin 19 / Arduino D13).
// Sin framework Arduino, sin UART: ideal para probar el bootloader.
// F_CPU = 16 MHz (definido en platformio.ini).

int main(void) {
  DDRB |= (1 << DDB5);   // PB5 como salida

  while (1) {
    PORTB |= (1 << PORTB5);   // LED ON
    _delay_ms(500);
    PORTB &= ~(1 << PORTB5);  // LED OFF
    _delay_ms(500);
  }
  return 0;
}
