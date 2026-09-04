#include "defs.h"
#include "ports.h"
#include "parts/pic.h"
#include "parts/pit.h"
#include "parts/fdc.h"
#include "idt.h"
#include "library/printf.h"
#include <stdint.h>

/* TODO List:
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

#define TAB_SIZE 4
static uint16_t *vga = (uint16_t *) 0xB8000;
void print_to_vga(const char *str) {
	static uint16_t cur_x = 0, cur_y = 0;
	for(uint32_t i = 0; ; i++) {
		uint8_t c = (uint8_t) str[i];
		switch(c) {
			case '\0': return;
			case '\t': cur_x += TAB_SIZE - cur_x % TAB_SIZE; continue;
			case '\n': cur_x = 0, cur_y++; continue;
			case '\b':
				if(cur_x == 0) {
					if(cur_y > 0) cur_y--;
					cur_x = 79;
				} else cur_x--;
				continue;
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
	uint8_t *fdc_dma_buf;
	map_entry_t *map_entries;
	uint16_t map_entry_count;
} bios_data_t;

static const char *map_type_names[] = {
	"Invalid", "Usable", "Reserved",
	"ACPI Data", "ACPI NVS", "Bad Mem"
};

asm_iface void loader_main(bios_data_t *collected_data) {
	disable_cursor();
	for(int i = 0; i < 80 * 25; i++) vga[i] = 0x1F00;
	char buffer[80];

	extern char _loader_base[], _real_end[];
	extern char _prot_end[], _prot_base[];
	print_to_vga("Section Bounds:\n");
	snprintf(buffer, 80, "\tReal: %p - %08tx (%p)\n\tProt: %p - %p (%08tx)\n\n",
		_loader_base, _loader_base + (uintptr_t) _real_end, _real_end,
		_prot_base, _prot_end, (ptrdiff_t)(_prot_end - _prot_base));
	print_to_vga(buffer);

	print_to_vga("BIOS E820 Table:\n");
	for(int i = 0; i < collected_data->map_entry_count; i++) {
		uint32_t type = collected_data->map_entries[i].type;
		if(type > 5) type = 0;
		snprintf(buffer, 80,
			"\tBase: %08X - Size: %08X - %s\n",
			collected_data->map_entries[i].base,
			collected_data->map_entries[i].size,
			map_type_names[type]);
		print_to_vga(buffer);
	}
	print_to_vga("\n");

	snprintf(buffer, 80,
		"BPB: %04X %04X %02X %02X %04X %02X %02X %04X %04X\n\n",
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

	pic_setup(0x20);
	__asm__ volatile("lidt %0" : : "m"(loader_idt));
	interrupts_on();

	pit_setup();
	fdc_init(collected_data->fdc_dma_buf);

	snprintf(buffer, 80, "%02X%02X\n",
		collected_data->fdc_dma_buf[510],
		collected_data->fdc_dma_buf[511]);
	print_to_vga(buffer);

	for(;;) {
		print_to_vga("|\b");  pit_delay(125*MSEC);
		print_to_vga("/\b");  pit_delay(125*MSEC);
		print_to_vga("-\b");  pit_delay(125*MSEC);
		print_to_vga("\\\b"); pit_delay(125*MSEC);
	}
}
