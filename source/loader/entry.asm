; Tell NASM .real.bss is a bss-like section
section .real.bss nobits

bits 16
section .real.text

; Clobbers AX, CX, DI, ES
extern _real_bss_start
extern _real_bss_end
clear_real_bss:
	; Heap shares ~32k block with the stack
	; Stage 1 set SS to 0 so that both
	; structures work seamlessly with PM32
	mov ax, ss
	mov es, ax

	; Get the start and end addresses
	; The size is always a multiple of 4 bytes
	lea ax, [_real_bss_start]
	lea cx, [_real_bss_end]

	mov di, ax ; STOSW uses ES:DI as its address
	sub cx, ax ; REP uses CX as its counter
	shr cx, 1  ; Total words in .real.bss
	xor ax, ax ; The value to write to memory
	rep stosw  ; CISC moment (memset)

	ret

section .real.entry
extern setup_gdt
extern goto_pm32
loader_entry:
	; Tiny-ish memory model
	; Stage 1 far-jumped to STAGE2_SEG:0 and so
	; CS contains the base for our 64k block
	; Linker script needs to match with stage 1
	mov ax, cs
	mov ds, ax

	call clear_real_bss

	; TODO: More foolproof A20
	in  al, 0x92
	or  al, 2
	out 0x92, al

	call setup_gdt

	; Technically we use ptr_farjmp (part of .bss) before
	; it gets cleared later on, but new values are written
	; to its entirety before it's used so it's ok
	lea ebx, [pm32_start]
	jmp goto_pm32

bits 32
section .text

; Clobbers EAX, ECX, EDI
extern _prot_bss_start
extern _prot_bss_end
clear_prot_bss:
	; Same story as with clear_real_bss except now
	; we get to use STOSD and the 32 bit registers

	lea eax, [_prot_bss_start]
	lea ecx, [_prot_bss_end]

	mov edi, eax
	sub ecx, eax
	shr ecx, 2
	xor eax, eax
	rep stosd

	ret

extern loader_main
pm32_start:
	call clear_prot_bss
	call loader_main
