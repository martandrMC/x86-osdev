OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0;
	.real : { *(.real.entry) *(.real*) }
	ASSERT(. <= 0x10000, "Real mode section exceeds 64 kB")

	.prot : ALIGN(16) {
		_prot_start = .;
		*(.text*) *(.rodata*) *(.data*)
		. = ALIGN(4);
		_prot_end = .;
	}

	.bss (NOLOAD) : ALIGN(16) {
		_bss_start = .;
		*(.bss*) *(COMMON)
		. = ALIGN(4);
		_bss_end = .;
	}
}
