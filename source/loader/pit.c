#include "pit.h"
#include "pic.h"
#include "idt.h"
#include "ports.h"

static volatile unsigned ticks = 0;
static void irq_handler(irq_state_t *state) {
	(void) state;
	ticks += 5;
	pic_send_eoi(0);
}

void pit_setup(void) {
	port_out8(0x43, 0x34); // 00: chan0, 11: lo+hi, 010: mode2, 0: bin
	port_out8(0x40, 0x4E), port_out8(0x40, 0x17); // 5966 cycles = 5ms
	register_isr(irq_handler, 0x20, IDT_PRESENT | IDT_INTR_GATE);
	pic_enable_line(0);
}

void pit_delay(unsigned ms) {
	interrupts_off();
	ticks = 0;
	interrupts_on();
	while(ticks < ms)
		interrupt_wait();
}
