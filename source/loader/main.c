#include "defs.h"
#include "ports.h"
#include "idt.h"
#include "library/printf.h"
#include <stdint.h>

/* TODO List:
	Interrupts
	Keyboard
	Floppy Driver
	Parse ELF
	Load Kernel
*/

void disable_cursor(void) {
	port_out8(0x3D4, 0x0A);
	uint8_t curr = port_in8(0x3D5);
	port_out8(0x3D5, curr | (1 << 5));
}

static uint16_t *vga = (uint16_t *) 0xB8000;
void print_to_vga(const char *str) {
	static uint16_t cur_x = 0, cur_y = 0;
	for(uint32_t i = 0; ; i++) {
		char c = str[i];
		switch(c) {
			case '\0': return;
			case '\r': cur_x = 0; continue;
			case '\n': cur_y++; continue;
			default: break;
		}
		uint32_t offset = cur_y * 80 + cur_x;
		vga[offset] = (vga[offset] & 0xFF00) | c;
		cur_x++;
	}
}

typedef struct packed bpb_data {
	uint16_t total_sects, sects_per_cyl;
	uint8_t head_count, boot_drive_id;
	uint16_t reserved_count;
	uint8_t fat_count, sects_per_clus;
	uint16_t sects_per_fat, entry_count;
} bpb_data_t;

typedef struct packed map_entry {
	uint32_t base, size, type;
} map_entry_t;

typedef struct packed bios_data {
	bpb_data_t *bpb_data;
	map_entry_t *map_entries;
	uint16_t map_entry_count;
} bios_data_t;

static const char *map_type_names[] = {
	"Invalid", "Usable", "Reserved",
	"ACPI Data", "ACPI NVS", "Bad Mem"
};

void keyboard_irq(irq_state_t *state) {
	(void) state;
	uint8_t code = port_in8(0x60);
	char buf[4]; snprintf(buf, 4, "%02X ", code);
	print_to_vga(buf);

	port_out8(0x20, 0x20);
}

void loader_main(bios_data_t *collected_data) {
	disable_cursor();
	for(int i = 0; i < 80 * 25; i++) vga[i] = 0x1F00;

	char buffer[80];
	for(int i = 0; i < collected_data->map_entry_count; i++) {
		uint32_t type = collected_data->map_entries[i].type;
		if(type > 5) type = 0;
		snprintf(buffer, 80,
			"Base: %08X - Size: %08X - %s\r\n",
			collected_data->map_entries[i].base,
			collected_data->map_entries[i].size,
			map_type_names[type]);
		print_to_vga(buffer);
	}
	print_to_vga("\r\n");

	snprintf(buffer, 80,
		"%04X %04X %02X %02X\r\n%04X %02X %02X %04X %04X\r\n",
		collected_data->bpb_data->total_sects,
		collected_data->bpb_data->sects_per_cyl,
		collected_data->bpb_data->head_count,
		collected_data->bpb_data->boot_drive_id,
		collected_data->bpb_data->reserved_count,
		collected_data->bpb_data->fat_count,
		collected_data->bpb_data->sects_per_clus,
		collected_data->bpb_data->sects_per_fat,
		collected_data->bpb_data->entry_count);
	print_to_vga(buffer);

	port_out8(0x21, ~2);
	port_out8(0xA1, ~0);

	register_isr(keyboard_irq, 0x09, IDT_PRESENT | IDT_INTR_GATE);
	__asm__ volatile("lidt %0" : : "m"(loader_idt));
	__asm__ volatile("sti");
}
