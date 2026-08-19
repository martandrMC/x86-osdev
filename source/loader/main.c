#include "defs.h"
#include "ports.h"
#include <stdint.h>

void disable_cursor(void) {
	port_out8(0x3D4, 0x0A);
	uint8_t curr = port_in8(0x3D5);
	port_out8(0x3D5, curr | (1 << 5));
}

char *num_to_hex(uint8_t chars, uint32_t num) {
	static char buf[9];
	for(uint32_t i = 0; i < chars; i++) {
		char c = '0' + (num & 0xF);
		if(c >= ':') c += 7;
		buf[chars - i - 1] = c;
		num >>= 4;
	}
	buf[chars] = '\0';
	return buf;
}

static uint16_t *vga = (uint16_t *) 0xB8000;
void print_to_vga(const char *str) {
	static uint8_t cur_x = 0, cur_y = 0;
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

cdecl void loader_main(bios_data_t *collected_data) {
	disable_cursor();
	for(int i = 0; i < 80 * 25; i++) vga[i] = 0x1F00;

	for(int i = 0; i < collected_data->map_entry_count; i++) {
		print_to_vga("Base: ");
		print_to_vga(num_to_hex(8, collected_data->map_entries[i].base));
		print_to_vga(" - ");
		print_to_vga("Size: ");
		print_to_vga(num_to_hex(8, collected_data->map_entries[i].size));
		print_to_vga(" - ");

		uint32_t type = collected_data->map_entries[i].type;
		if(type > 5) type = 0;
		print_to_vga(map_type_names[type]);
		print_to_vga("\r\n");
	}
	print_to_vga("\r\n");

	print_to_vga(num_to_hex(4, collected_data->bpb_data->total_sects));
	print_to_vga(" ");
	print_to_vga(num_to_hex(4, collected_data->bpb_data->sects_per_cyl));
	print_to_vga(" ");
	print_to_vga(num_to_hex(2, collected_data->bpb_data->head_count));
	print_to_vga(" ");
	print_to_vga(num_to_hex(2, collected_data->bpb_data->boot_drive_id));
	print_to_vga("\r\n");

	print_to_vga(num_to_hex(4, collected_data->bpb_data->reserved_count));
	print_to_vga(" ");
	print_to_vga(num_to_hex(2, collected_data->bpb_data->fat_count));
	print_to_vga(" ");
	print_to_vga(num_to_hex(2, collected_data->bpb_data->sects_per_clus));
	print_to_vga(" ");
	print_to_vga(num_to_hex(4, collected_data->bpb_data->sects_per_fat));
	print_to_vga(" ");
	print_to_vga(num_to_hex(4, collected_data->bpb_data->entry_count));
	print_to_vga("\r\n");

	print_to_vga("\r\n");
}
