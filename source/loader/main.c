#include "ports.h"

unsigned short *vga = (unsigned short *) 0xB8000;
const char message[] = "Hellorld!";

void disable_cursor(void) {
	outb(0x3D4, 0x0A);
	u8 curr = inb(0x3D5);
	outb(0x3D5, curr | (1 << 5));
}

void loader_main(void) {
	disable_cursor();

	for(u32 i = 0; i < 80 * 25; i++) vga[i] = 0x1F00;
	for(u32 i = 0; i < sizeof message; i++) vga[i] |= message[i];

	for(;;) asm volatile("hlt");
}
