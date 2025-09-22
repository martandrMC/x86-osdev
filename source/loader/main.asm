%include "source/loader/tables.asm"
LOADER_BASE equ 0x08000
org 0x0000

bits 16
real_entry:
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
gdt_begin gdt, LOADER_BASE
	gdt_entry code, LOADER_BASE, 0x00078, 0b10011010_1100
	gdt_entry data, LOADER_BASE, 0x00078, 0b10010010_1100
	gdt_entry stak, LOADER_BASE, 0xF8500, 0b10010110_0100
	gdt_entry flat, 0,           0xFFFFF, 0b10010010_1100
gdt_end

prot_entry:
	mov ax, 0x10
	mov ds, ax

	mov ax, 0x20
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov ax, 0x18
	mov ss, ax
	xor esp, esp

	call main
	hlt

main:
	mov edi, 0xB8000
	mov ax, 0x0E41
	stosw
	ret
