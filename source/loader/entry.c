void loader_entry(void) {
	asm volatile ("movw $0x0E41, %%fs:0xB8000" : : : "memory");
}
