bits 16
section .real.text

struc given_e820
	.base: resq 1
	.size: resq 1
	.type: resd 1
endstruc

struc stored_e820
	.base: resd 1
	.size: resd 1
	.type: resd 1
endstruc

; Heap segment in DS and ES
; Continuation value in EBX
; Clobbers ECX, EDX, DI
extern arena_alloc
get_e820_entry:
	push ax

	xor eax, eax
	mov ax, 0xE820
	mov edx, 'PAMS'
	xor ecx, ecx
	mov cx, given_e820_size
	lea di, [e820_buffer]

	int 0x15
	jnc .continue
	cmp eax, edx
	je  .continue
	cmp cl, 20
	jae .continue

	pop ax
	stc
	ret
	.continue:

	push ebx
	mov bx, stored_e820_size
	call arena_alloc

	mov eax, [e820_buffer + given_e820.base]
	mov [bx + stored_e820.base], eax

	mov eax, [e820_buffer + given_e820.size]
	mov [bx + stored_e820.size], eax

	mov eax, [e820_buffer + given_e820.type]
	mov [bx + stored_e820.type], eax

	pop ebx
	pop ax
	ret

; Heap segment in ES
; Returns entry count in AX
; Returns entry list addr in BX
; Clobbers ECX, EDX, DI
extern arena_alloc
global collect_e820
collect_e820:
	push ds
	mov ax, es
	mov ds, ax

	xor bx, bx
	call arena_alloc
	push bx

	xor ebx, ebx
	xor ax, ax
	.repeat:
		call get_e820_entry
		jc  .exit
		inc ax
		cmp ax, 32
		je  .exit
	test ebx, ebx
	jnz .repeat
	.exit:

	pop bx
	pop ds
	ret

section .real.bss
e820_buffer: resb given_e820_size
