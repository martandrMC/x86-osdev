#ifndef PORTS_H
#define PORTS_H

#include "defs.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wattributes"
force_inline u8 inb(u16 port) {
	u8 val;
	asm volatile("inb %%dx, %%al" : "=a" (val) : "d" (port));
	return val;
}

force_inline void outb(u16 port, u8 value) {
	asm volatile ("outb %%al, %%dx": :"d" (port), "a" (value));
}
#pragma GCC diagnostic pop

#endif
