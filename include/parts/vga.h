#ifndef PARTS_VGA_H
#define PARTS_VGA_H

#include <stdint.h>

void vga_init(uint8_t tab_size);
void vga_putc(char c);
void vga_puts(const char *str);

#endif
