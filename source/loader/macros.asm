%macro go_protected 0
	mov edx, cr0
	or  edx, 1
	mov cr0, edx
	jmp SEG_CODE32:.pm32

	.pm32: bits 32
	mov dx, SEG_DATA
	mov ds, dx
	mov es, dx

	mov dx, SEG_STAK32
	mov ss, dx

	mov dx, SEG_FLAT
	mov fs, dx
	mov gs, dx
%endmacro

%macro go_unreal 0
	jmp SEG_CODE16:.pm16

	.pm16: bits 16
	mov dx, SEG_STAK16
	mov ss, dx

	mov edx, cr0
	and edx, ~1
	mov cr0, edx
	jmp (LOADER_BASE >> 4):.um

	.um:
	mov dx, (STACK_BASE >> 4)
	mov ss, dx
	mov sp, STACK_SIZE
%endmacro

; gdt_entry label, base, limit, access+flags
%macro gdt_entry 4
	.%1:
	dw %3 & 0xFFFF              ; limit[15:0]
	dw %2 & 0xFFFF              ; base[15:0]
	db %2   >> 16 & 0xFF        ; base[23:16]
	db (%4) >>  4 & 0xFF | 0x80 ; access[7:0] | PRESENT
	%assign flag (%4) & 0xF     ; flag[3:0]
	%assign ulim %3 >> 16 & 0xF ; limit[19:16]
	db flag << 4 | ulim         ; {flag, ulim}
	%undef flag
	%undef ulim
	db %2 >> 24 & 0xFF          ; base[31:24]
%endmacro
