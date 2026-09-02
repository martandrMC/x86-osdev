bits 32
section .text
VECTOR_COUNT equ 64

global register_isr
register_isr:
	mov ecx, [esp +  8]
	cmp ecx, VECTOR_COUNT
	jb  .in_range
	xor eax, eax
	dec eax
	ret

	.in_range:
	shl ecx, 2

	mov al, [esp + 12]
	mov [loader_idt._bgn + ecx * 2 + 5], al
	mov eax, [stub_ptrs + ecx]
	mov [loader_idt._bgn + ecx * 2 + 0], ax
	shr eax, 16
	mov [loader_idt._bgn + ecx * 2 + 6], ax

	mov eax, [esp +  4]
	xchg [handler_ptrs + ecx], eax
	ret

common_stub:
	pusha
	mov eax, [esp + 32]
	mov eax, [handler_ptrs + eax * 4]
	test eax, eax
	jz .exit

	push esp
	call eax
	add esp, 4

	.exit:
	popa
	add esp, 8
	iret

%define has_ecode_8  1
%define has_ecode_10 1
%define has_ecode_11 1
%define has_ecode_12 1
%define has_ecode_13 1
%define has_ecode_14 1
%define has_ecode_17 1
%define has_ecode_21 1
%define has_ecode_29 1
%define has_ecode_30 1

%assign i 0
%rep VECTOR_COUNT
stub_%[i]:
	%ifndef has_ecode_%[i]
	push 0
	%endif
	push i
	jmp common_stub
%assign i i+1
%endrep

section .data
stub_ptrs:
%assign i 0
%rep VECTOR_COUNT
dd stub_%[i]
%assign i i+1
%endrep

global loader_idt
loader_idt:
	align 4
	._length:  dw ._end - ._bgn - 1
	._bgn_ptr: dd ._bgn
._bgn:
	%rep VECTOR_COUNT
	dw 0, 0x08, 0, 0
	%endrep
._end:

section .bss
handler_ptrs:
resd VECTOR_COUNT
