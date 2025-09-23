%include "source/loader/tables.asm"
LOADER_BASE equ 0x08000
org 0x0000

bits 16
loader_realmode:
	xor ah, ah
	mov al, 3
	int 0x10

	cli
	lgdt [gdt]

	in al, 0x92
	or al, 2
	out 0x92, al

	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp 0x8:prot_entry

bits 32
table_begin gdt, LOADER_BASE
	.null: dq 0
	gdt_entry code, LOADER_BASE, 0x00077, 0b10011010_1100
	gdt_entry data, LOADER_BASE, 0x00077, 0b10010010_1100
	gdt_entry stak, LOADER_BASE, 0xFFFF8, 0b10010110_1100
	gdt_entry flat, 0,           0xFFFFF, 0b10010010_1100
table_end

table_begin idt, LOADER_BASE
times 256 dq 0
table_end

interrupt:
	mov word [fs:0xB8000], 0x0421
	hlt

prot_entry:
	mov ax, 0x10
	mov ds, ax
	mov es, ax

	mov ax, 0x18
	mov ss, ax
	xor esp, esp

	mov ax, 0x20
	mov fs, ax
	mov gs, ax

	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	lea ebx, [idt._bgn + 0x0D * 8]
	lea eax, [interrupt]
	mov word [ebx + 0], ax
	mov word [ebx + 2], 0x0008
	mov byte [ebx + 4], 0x00
	mov byte [ebx + 5], 0x8E
	shr eax, 16
	mov word [ebx + 6], ax

	lidt [idt]
	sti

	call main
	hlt

main:
	; intentional segfault
	mov byte [0x78000], 0xFF
	ret
