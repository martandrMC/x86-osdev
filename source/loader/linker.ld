OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0;
	.real : { *(.real) *(.real*) }
	ASSERT(. <= 0x10000, "Real mode section exceeds 64 kB")
	.prot : { *(.text*) *(.rodata*) *(.data*) }
	.bss (NOLOAD) : ALIGN(16) { *(.bss*) *(COMMON) }
}
