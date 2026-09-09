#include "defs.h"
#include "ports.h"
#include "parts/pic.h"
#include "parts/pit.h"
#include "parts/fdc.h"
#include "parts/vga.h"
#include "idt.h"
#include "library/snprintf.h"
#include <stdint.h>

/* TODO List:
	FAT12 Reading
	Split Makefiles
	Keyboard
	Parse ELF
	Load Kernel
*/

typedef struct packed map_entry {
	uint32_t base, size, type;
} map_entry_t;

typedef struct packed bios_data {
	media_info_t *media_info;
	uint8_t *dma_buffer;
	uint16_t dma_size;
	map_entry_t *map_entries;
	uint16_t map_entry_count;
} bios_data_t;

static const char *map_type_names[] = {
	"Invalid", "Usable", "Reserved",
	"ACPI Data", "ACPI NVS", "Bad Mem"
};

static void dump_memory(uint8_t *addr, unsigned count) {
	char buf[80];
	for(unsigned i = 0; i < count; i += 16) {
		snprintf(buf, 80, "%p \xB3 ", addr); vga_puts(buf);
		for(unsigned j = 0; j < 16; j++) {
			snprintf(buf, 80, "%02X ", addr[j]);
			vga_puts(buf);
		}
		vga_puts("\xB3 ");
		for(unsigned j = 0; j < 16; j++) {
			uint8_t c = addr[j];
			vga_putc(c < 32 ? '.' : c);
		}
		vga_putc('\n');
		addr = &addr[16];
	}
}

asm_iface void loader_main(bios_data_t *collected_data) {
	pic_setup(0x20); pit_setup();
	__asm__ volatile("lidt %0" : : "m"(loader_idt));
	interrupts_on();
	// Breakpoints Past Here //

	vga_init(4);
	char buffer[80];

	extern char _loader_base[], _real_end[];
	extern char _prot_end[], _prot_base[];
	vga_puts("Section Bounds:\n");
	snprintf(buffer, 80, "\tReal: %p - %08tx (%p)\n\tProt: %p - %p (%08tx)\n\n",
		_loader_base, _loader_base + (uintptr_t) _real_end, _real_end,
		_prot_base, _prot_end, (ptrdiff_t)(_prot_end - _prot_base));
	vga_puts(buffer);

	vga_puts("BIOS E820 Table:\n");
	for(int i = 0; i < collected_data->map_entry_count; i++) {
		uint32_t type = collected_data->map_entries[i].type;
		if(type > 5) type = 0;
		snprintf(buffer, 80,
			"\tBase: %08X - Size: %08X - %s\n",
			collected_data->map_entries[i].base,
			collected_data->map_entries[i].size,
			map_type_names[type]);
		vga_puts(buffer);
	}
	vga_puts("\n");

	snprintf(buffer, 80,
		"BPB: %04X %04X %02X %02X\n\n",
		collected_data->media_info->total_sects,
		collected_data->media_info->sects_per_trk,
		collected_data->media_info->head_count,
		collected_data->media_info->boot_drive_id);
	vga_puts(buffer);

	fdc_init(collected_data->media_info,
		collected_data->dma_buffer, collected_data->dma_size);

	static uint8_t sector[512];
	fdc_read(sector, 0, 1);
	dump_memory(sector, 128);

	for(;;) {
		vga_puts("|\b");  pit_delay(125*MSEC);
		vga_puts("/\b");  pit_delay(125*MSEC);
		vga_puts("-\b");  pit_delay(125*MSEC);
		vga_puts("\\\b"); pit_delay(125*MSEC);
	}
}
