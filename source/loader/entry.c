#define asm_def __attribute__((cdecl)) extern

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;

asm_def void put_vga(uint offset, ushort value);
asm_def void clear_screen(void);
asm_def void rm_call(void (*real_ptr)(void));

void print(const char *str) {
	for(uint i = 0; ; i++) {
		uchar c = str[i];
		if(c == '\0') break;
		put_vga(i, c | (0x0E << 8));
	}
}

void loader_entry(void) {
	rm_call(clear_screen);
	print("Hellorld!");
	asm volatile ("hlt");
}
