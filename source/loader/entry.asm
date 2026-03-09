LOADER_BASE equ 0x08000
LOADER_SIZE equ 0x78000
STACK_BASE  equ 0x00500
STACK_SIZE  equ 0x07B00

; gdt_entry label, base, limit, access+flags
%macro gdt_entry 4
	.%1:
	SEG_%1 equ .%1 - ._bgn
	dw %3 & 0xFFFF              ; limit[15:0]
	dw %2 & 0xFFFF              ; base[15:0]
	db %2   >> 16 & 0xFF        ; base[23:16]
	db (%4) >>  4 & 0xFF        ; access[7:0]
	%assign flag (%4) & 0xF     ; flag[3:0]
	%assign ulim %3 >> 16 & 0xF ; limit[19:16]
	db flag << 4 | ulim         ; {flag, ulim}
	%undef flag
	%undef ulim
	db %2 >> 24 & 0xFF          ; base[31:24]
%endmacro

section .real.gdt
loader_gdt:
	dw ._end - ._bgn - 1
	dd LOADER_BASE + ._bgn
._bgn:
	.null: dq 0
	gdt_entry CODE16, LOADER_BASE, 0x0FFFF,                 0b1001_1010_0000
	gdt_entry STAK16, STACK_BASE,  0x0FFFF,                 0b1001_0010_0000

	gdt_entry CODE32, LOADER_BASE, (LOADER_SIZE - 1) >> 12, 0b1001_1010_1100
	gdt_entry STAK32, STACK_BASE,   STACK_SIZE  - 1,        0b1001_0010_0100
	gdt_entry DATA32, LOADER_BASE, (LOADER_SIZE - 1) >> 12, 0b1001_0010_1100
	gdt_entry FLAT32, 0,           0xFFFFF,                 0b1001_0010_1100
._end:

section .real
loader_entry: bits 16
	in al, 0x92
	or al, 2
	out 0x92, al

	lgdt [loader_gdt]

	lea ax, [.pm_entry]
	jmp goto_protected
	.pm_entry: bits 32

	mov esp, STACK_SIZE
	mov ebp, esp
	push ebp

	extern loader_main
	jmp loader_main

global goto_protected
goto_protected: bits 16
	cli

	mov edx, cr0
	or  edx, 1
	mov cr0, edx

	jmp SEG_CODE32:.pm32
	.pm32: bits 32

	mov dx, SEG_STAK32
	mov ss, dx

	mov dx, SEG_DATA32
	mov ds, dx
	mov es, dx

	mov dx, SEG_FLAT32
	mov fs, dx
	mov gs, dx

	jmp ax

global goto_unreal
goto_unreal: bits 32
	jmp SEG_CODE16:.pm16
	.pm16: bits 16

	mov dx, SEG_STAK16
	mov ss, dx

	mov edx, cr0
	and edx, ~1
	mov cr0, edx

	jmp (LOADER_BASE >> 4):.rm
	.rm:

	mov dx, (STACK_BASE >> 4)
	mov ss, dx

	mov dx, (LOADER_BASE >> 4)
	mov ds, dx
	mov es, dx

	xor dx, dx
	mov fs, dx
	mov gs, dx

	sti

	jmp ax
