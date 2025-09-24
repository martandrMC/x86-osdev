OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0;
	.entry  : { *(.entry) }
	.text   : { *(.text) }
	.rodata : { *(.rodata) }
	.data   : { *(.data) }
	.bss    : { *(.bss) }
}
