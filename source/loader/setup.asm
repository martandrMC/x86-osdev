%include "source/loader/macros.asm"

LOADER_BASE equ 0x08000
STACK_BASE  equ 0x00500
STACK_SIZE  equ 0x0B00

SEG_CODE16 equ 0x08
SEG_STAK16 equ 0x10
SEG_CODE32 equ 0x18
SEG_STAK32 equ 0x20
SEG_DATA   equ 0x28
SEG_FLAT   equ 0x30

section .entry
bits 16
loader_realmode:
	mov ax, (STACK_BASE >> 4)
	mov ss, ax
	mov sp, STACK_SIZE

	in al, 0x92
	or al, 2
	out 0x92, al
	cli

	lgdt [loader_gdt]
	go_protected
	xor esp, esp

	extern loader_entry
	jmp loader_entry

global rm_call
rm_call: bits 32
	mov ax, [esp + 4]

	mov ecx, esp
	go_unreal
	push ecx

	pusha
	sti
	jmp ax

global rm_ret
rm_ret: bits 16
	cli
	popa

	pop ecx
	go_protected
	mov esp, ecx

	ret

global put_vga
put_vga: bits 32
	push ebx
	mov ebx, [esp + 8]
	mov ax,  [esp + 12]
	mov [fs:0xB8000 + ebx * 2], ax
	pop ebx
	ret

global clear_screen
clear_screen: bits 16
	xor ah, ah
	mov al, 3
	int 0x10

	jmp rm_ret

global loader_gdt
loader_gdt:
	dw ._end - ._bgn - 1
	dd LOADER_BASE + ._bgn
._bgn:
	.null: dq 0
	gdt_entry code16, LOADER_BASE, 0x0FFFF, 0b10011010_0000
	gdt_entry stak16, STACK_BASE,  0x0FFFF, 0b10010010_0000
	gdt_entry code32, LOADER_BASE, 0x00077, 0b10011010_1100
	gdt_entry stak32, LOADER_BASE, 0xFFFF8, 0b10010110_1100
	gdt_entry data,   LOADER_BASE, 0x00077, 0b10010010_1100
	gdt_entry flat,   0,           0xFFFFF, 0b10010010_1100
._end:
