#include "ports.h"

void disable_cursor(void) {
	outb(0x3D4, 0x0A);
	u8 curr = inb(0x3D5);
	outb(0x3D5, curr | (1 << 5));
}

char *num_to_hex(u8 chars, u32 num) {
	static char buf[9];
	for(u32 i = 0; i < chars; i++) {
		char c = '0' + (num & 0xF);
		if(c >= ':') c += 7;
		buf[chars - i - 1] = c;
		num >>= 4;
	}
	buf[chars] = '\0';
	return buf;
}

static u16 *vga = (u16 *) 0xB8000;
void print_to_vga(const char *str) {
	static u8 cur_x = 0, cur_y = 0;
	for(u32 i = 0; ; i++) {
		char c = str[i];
		switch(c) {
			case '\0': return;
			case '\r': cur_x = 0; continue;
			case '\n': cur_y++; continue;
			default: break;
		}
		u32 offset = cur_y * 80 + cur_x;
		vga[offset] = (vga[offset] & 0xFF00) | c;
		cur_x++;
	}
}

typedef struct map_entry {
	u32 base_flags;
	u32 size;
} map_entry_t;

typedef struct bios_data {
	map_entry_t *map_entries;
	u16 map_entry_count;
	u8  boot_disk_id;
} bios_data_t;

cdecl void loader_main(bios_data_t *collected_data) {
	disable_cursor();
	for(u32 i = 0; i < 80 * 25; i++) vga[i] = 0x1F00;

	for(u32 i = 0; i < collected_data->map_entry_count; i++) {
		u32 size = collected_data->map_entries[i].size;
		u32 base = collected_data->map_entries[i].base_flags & ~0xF;
		u8 flags = collected_data->map_entries[i].base_flags &  0xF;
		print_to_vga(num_to_hex(8, base));
		print_to_vga(" ");
		print_to_vga(num_to_hex(8, size));
		print_to_vga(" ");
		print_to_vga(num_to_hex(2, flags));
		print_to_vga("\r\n");
	}
}
