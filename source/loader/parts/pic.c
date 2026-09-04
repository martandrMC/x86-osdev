#include "parts/pic.h"
#include "ports.h"

#define PIC1_CMD 0x20
#define PIC1_DAT 0x21
#define PIC2_CMD 0xA0
#define PIC2_DAT 0xA1

void pic_setup(uint8_t irq_base) {
	port_out8(PIC1_CMD, 0x11);     port_out8(PIC2_CMD, 0x11);
	port_out8(PIC1_DAT, irq_base); port_out8(PIC2_DAT, irq_base + 8);
	port_out8(PIC1_DAT, 1 << 2);   port_out8(PIC2_DAT, 2);
	port_out8(PIC1_DAT, 0x01);     port_out8(PIC2_DAT, 0x01);
	port_out8(PIC1_DAT, ~0);       port_out8(PIC2_DAT, ~0);
}

void pic_send_eoi(uint8_t id) {
	if(id > 15) return;
	if(id > 7) port_out8(PIC2_CMD, 0x20);
	port_out8(PIC1_CMD, 0x20);
}

void pic_enable_line(uint8_t id) {
	if(id > 15) return;
	uint16_t port = (id > 7 ? (id -= 8, PIC2_DAT) : PIC1_DAT);
	uint8_t mask = port_in8(port);
	port_out8(port, mask & ~(1 << id));
}

void pic_disable_line(uint8_t id) {
	if(id > 15) return;
	uint16_t port = (id > 7 ? (id -= 8, PIC2_DAT) : PIC1_DAT);
	uint8_t mask = port_in8(port);
	port_out8(port, mask | (1 << id));
}
