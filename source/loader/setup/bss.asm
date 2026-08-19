bits 16
section .real.text

; Heap segment in ES
; Clobbers AX, CX, DI
extern _real_bss_start
extern _real_bss_end
global clear_real_bss
clear_real_bss:
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

bits 32
section .text

; Clobbers EAX, ECX, EDI
extern _prot_bss_start
extern _prot_bss_end
global clear_prot_bss
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
