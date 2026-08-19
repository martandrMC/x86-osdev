#ifndef PORTS_H
#define PORTS_H

#include "defs.h"
#include <stdint.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wattributes"
#pragma GCC diagnostic ignored "-Wunused-function"
force_inline uint8_t port_in8(uint16_t port) {
	uint8_t val;
	__asm__ volatile("inb %%dx, %%al" : "=a" (val) : "d" (port));
	return val;
}

force_inline void port_out8(uint16_t port, uint8_t value) {
	__asm__ volatile ("outb %%al, %%dx": :"d" (port), "a" (value));
}

force_inline uint8_t port_in16(uint16_t port) {
	uint16_t val;
	__asm__ volatile("inw %%dx, %%ax" : "=a" (val) : "d" (port));
	return val;
}

force_inline void port_out16(uint16_t port, uint16_t value) {
	__asm__ volatile ("outw %%ax, %%dx": :"d" (port), "a" (value));
}

force_inline uint8_t port_in32(uint16_t port) {
	uint32_t val;
	__asm__ volatile("ind %%dx, %%eax" : "=a" (val) : "d" (port));
	return val;
}

force_inline void port_out32(uint16_t port, uint32_t value) {
	__asm__ volatile ("outd %%eax, %%dx": :"d" (port), "a" (value));
}
#pragma GCC diagnostic pop

#endif
