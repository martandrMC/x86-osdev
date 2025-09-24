LOADER_BASE equ 0x08000

section .entry
bits 16
loader_realmode:
	xor ah, ah
	mov al, 3
	int 0x10

	cli
	lgdt [initial_gdt]

	in al, 0x92
	or al, 2
	out 0x92, al

	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp 0x8:loader_protmode

bits 32
loader_protmode:
	mov ax, 0x10
	mov ds, ax
	mov es, ax

	mov ax, 0x18
	mov ss, ax
	xor esp, esp

	mov ax, 0x20
	mov fs, ax
	mov gs, ax

	extern loader_entry
	call loader_entry
	hlt

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

initial_gdt:
	dw ._end - ._bgn - 1
	dd LOADER_BASE + ._bgn
._bgn:
	.null: dq 0
	gdt_entry code, LOADER_BASE, 0x00077, 0b10011010_1100
	gdt_entry data, LOADER_BASE, 0x00077, 0b10010010_1100
	gdt_entry stak, LOADER_BASE, 0xFFFF8, 0b10010110_1100
	gdt_entry flat, 0,           0xFFFFF, 0b10010010_1100
._end:
