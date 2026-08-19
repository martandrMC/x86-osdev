OUTPUT_FORMAT(binary)

SECTIONS {
	_loader_base = 0x8000;
	_heap_base = 0x0500;

	.real 0 : AT(_loader_base) {
		_real_start = .; *(.real.entry) *(.real.text*)
		. = ALIGN(4); *(.real.data*)
		. = ALIGN(2); _real_end = .;
	}

	.real.bss _heap_base (NOLOAD) : {
		_real_bss_start = .; *(.real.bss*)
		. = ALIGN(2); _real_bss_end = .;
	}

	_real_size = _real_end - _real_start;
	_prot_base = ALIGN(_loader_base + _real_size, 16);
	ASSERT(_real_size <= 0x10000, "Real mode section exceeds 64 kiB")

	. = _prot_base;
	.prot : AT(_prot_base) {
		_prot_start = .; *(.text*)
		. = ALIGN(4); *(.rodata*)
		. = ALIGN(4); *(.data*)
		. = ALIGN(4); _prot_end = .;
	}

	.prot.bss (NOLOAD) : ALIGN(16) {
		_prot_bss_start = .; *(.bss*) *(COMMON)
		. = ALIGN(4); _prot_bss_end = .;
	}

	/DISCARD/ : {
		*(.comment) *(.eh_frame)
	}
}
