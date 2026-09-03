bits 16
section .real.text

; Allocation size in BX
; Returned pointer in BX
global arena_alloc
arena_alloc:
	push ax
	xor ax, ax
	mov al, 3

	; Round up size to next multiple of 4
	add bx, ax ; Bump up the size by 3
	not ax     ; Invert to mask out low bits
	and bx, ax ; Correct the overshoot

	; Add BX to arena_ptr whilst bringing
	; old arena_ptr back into BX
	xadd [cs:arena_ptr], bx

	pop ax
	ret

section .real.data
extern _real_bss_end
arena_ptr: dw _real_bss_end
