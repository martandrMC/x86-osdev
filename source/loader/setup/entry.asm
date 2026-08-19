bits 16
section .real.text

struc bios_data
	.bpb_addr resd 1
	.map_addr resd 1
	.map_size resw 1
endstruc

; Clobbers AL
enable_a20:
	in  al, 0x92
	or  al, 2
	out 0x92, al
	ret

section .real.entry
extern clear_real_bss
extern collect_bpb
extern collect_e820
extern setup_gdt
extern goto_pm32
loader_entry:
	; Tiny-ish memory model
	; Stage 1 far-jumped to STAGE2_SEG:0 and so
	; CS contains the base for our 64k block
	; Linker script needs to match with stage 1
	mov ax, cs
	mov ds, ax

	; Heap shares ~32k block with the stack
	; Stage 1 set SS to 0 so that both
	; structures work seamlessly with PM32
	mov ax, ss
	mov es, ax

	call clear_real_bss

	; DX has been left untouched and should still
	; contain 0x07C0 from when stage 1 set it
	call collect_bpb
	mov [es:collected_data + bios_data.bpb_addr], bx

	call collect_e820
	mov [es:collected_data + bios_data.map_addr], bx
	mov [es:collected_data + bios_data.map_size], ax

	call enable_a20
	call setup_gdt

	; Technically we use jmp_buffer (part of .bss) before
	; it gets cleared later on, but new values are written
	; to its entirety before it's used so it's ok
	lea ebx, [pm32_start]
	jmp goto_pm32

section .real.bss
collected_data: resb bios_data_size

bits 32
section .text

extern clear_prot_bss
extern loader_main
pm32_start:
	call clear_prot_bss

	lea eax, [collected_data]
	push eax
	call loader_main
	add esp, 4

	.die: hlt
	jmp .die
