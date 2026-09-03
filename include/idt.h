#ifndef IDT_H
#define IDT_H

#include "defs.h"
#include <stdint.h>

#define IDT_INTR_GATE 0x0E
#define IDT_TRAP_GATE 0x0F
#define IDT_PRESENT   0x80

typedef struct irq_state {
	uint32_t edi, esi, ebp, esp;
	uint32_t ebx, edx, ecx, eax;
	uint32_t vector, ecode, eip;
} irq_state_t;

typedef void (*irq_handler_f)(irq_state_t *state);
asm_iface irq_handler_f register_isr(
	irq_handler_f new_isr, uint8_t vector, uint8_t attrib);

extern char loader_idt[];

#define interrupt_wait() __asm__ volatile("hlt")
#define interrupts_off() __asm__ volatile("cli")
#define interrupts_on() __asm__ volatile("sti")
#define load_idt(ptr) __asm__ volatile("lidt %0" : : "m"(ptr));

#endif
