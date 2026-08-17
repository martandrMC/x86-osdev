bits 16
section .real.text

; Allocation size in BX
; Returned pointer in BX
global arena_alloc
arena_alloc:
	xchg bx, [cs:arena_ptr] ; Bring old pointer to AX
	add [cs:arena_ptr], bx  ; Add it back onto offset
	ret

; Power-of-two to align by in CL
; Clobbers BX
global arena_align
arena_align:
	mov bx, 1  ; Start with 1
	shl bx, cl ; Shift it up CL bits
	dec bx     ; Now have CL ones

	add [cs:arena_ptr], bx ; Bump up the pointer
	not bx                 ; Invert to mask out low bits
	and [cs:arena_ptr], bx ; Correct the overshoot

	ret

section .real.data
extern _real_bss_end
arena_ptr: dw _real_bss_end
