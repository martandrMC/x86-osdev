#include "parts/pit.h"
#include "parts/pic.h"
#include "idt.h"
#include "ports.h"
#include <stddef.h>

#define MAX_TIMEOUTS 4
typedef struct timeout {
	timeout_f callback;
	unsigned ticks_remain;
} timeout_t;

static struct {
	unsigned delay_ticks;
	timeout_t timeouts[MAX_TIMEOUTS];
} state;

static void irq_handler(irq_state_t *dummy) {
	(void) dummy;
	state.delay_ticks++;
	for(int i = 0; i < MAX_TIMEOUTS; i++) {
		timeout_t *to = &state.timeouts[i];
		if(to->ticks_remain > 0) to->ticks_remain--;
		else if(to->callback != NULL) {
			to->callback();
			to->callback = NULL;
		}
	}
	pic_send_eoi(0);
}

void pit_setup(void) {
	port_out8(0x43, 0x34); // 00: chan0, 11: lo+hi, 010: mode2, 0: bin
	port_out8(0x40, 0x4E), port_out8(0x40, 0x17); // 5966 cycles = 5us
	register_isr(irq_handler, 0x20, IDT_PRESENT | IDT_INTR_GATE);
	pic_enable_line(0);
}

void pit_delay(unsigned usec) {
	interrupts_off();
	unsigned ticks = (usec - 1) / 5000 + 1;
	state.delay_ticks = 0;
	interrupts_on();

	while(state.delay_ticks < ticks)
		interrupt_wait();
}

int pit_register_timeout(timeout_f callback, unsigned usec) {
	if(usec == 0) return -1;
	interrupts_off();
	for(int i = 0; i < MAX_TIMEOUTS; i++) {
		timeout_t *to = &state.timeouts[i];
		if(to->callback != NULL) continue;
		to->ticks_remain = (usec - 1) / 5000 + 1;
		to->callback = callback;
		interrupts_on();
		return i;
	}
	interrupts_on();
	return -1;
}

void pit_cancel_timeout(timeout_f callback, int timeout_id) {
	if(timeout_id == -1) return;
	interrupts_off();
	timeout_t *to = &state.timeouts[timeout_id];
	if(to->callback == callback)
		to->callback = NULL, to->ticks_remain = 0;
	interrupts_on();
}
