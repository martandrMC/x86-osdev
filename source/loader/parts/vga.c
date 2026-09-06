#include "parts/vga.h"
#include "ports.h"

#define CRTC_IDX 0x3D4
#define CRTC_DAT 0x3D5

static struct {
	uint16_t *vram;
	uint8_t curr_x, curr_y;
	uint8_t tab_size;
} state;

static void disable_cursor(void) {
	port_out8(CRTC_IDX, 0x0A);
	uint8_t curr = port_in8(CRTC_DAT);
	port_out8(CRTC_DAT, curr | (1 << 5));
}

static void set_offset(uint16_t words) {
	port_out8(CRTC_IDX, 0x0C);
	port_out8(CRTC_DAT, words >> 8 & 0xFF);
	port_out8(CRTC_IDX, 0x0D);
	port_out8(CRTC_DAT, words & 0xFF);
}

static void clear_line(uint8_t y) {
	uint16_t offset = y * 80;
	for(uint16_t i = 0; i < 80; i++)
		state.vram[offset + i] = 0x1F20;
}

void vga_init(uint8_t tab_size) {
	state.vram = (uint16_t *) 0xB8000;
	state.tab_size = tab_size;

	disable_cursor();
	for(uint8_t i = 0; i < 25; i++)
		clear_line(i);
}

static void new_line(void) {
	state.curr_x = 0;
	if(state.curr_y < 49) state.curr_y++;
	else state.curr_y = 25;
	if(state.curr_y < 24) return;
	clear_line(state.curr_y);
	set_offset((state.curr_y - 24) * 80);
	clear_line(state.curr_y - 25);
}

static void add_char(uint8_t c) {
	uint16_t offset = state.curr_y * 80 + state.curr_x;
	state.vram[offset] = 0x1F00 | c;

	if(state.curr_y >= 25) {
		offset -= 25 * 80;
		state.vram[offset] = 0x1F00 | c;
	}

	if(++state.curr_x == 80) new_line();
}

void vga_putc(char c) {
	switch(c) {
		case '\b':
			if(state.curr_x > 0) state.curr_x--;
			break;
		case '\t':;
			uint8_t pad = state.tab_size - state.curr_x % state.tab_size;
			for(int i = 0; i < pad; i++) add_char(' ');
			break;
		case '\n': new_line(); break;
		default: add_char(c); break;
	}
}

void vga_puts(const char *str) {
	for(uint32_t i = 0; ; i++) {
		char c = str[i];
		if(c == '\0') break;
		vga_putc(c);
	}
}
