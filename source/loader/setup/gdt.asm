bits 16
section .real.text

; Clobbers EAX
extern _loader_base
global setup_gdt
setup_gdt:
	; Can't use _loader_base in comptime math
	; because it's a linker-provided symbol,
	; so adjust addresses in the GDT at runtime

	; Apply offset to make GDT pointer in GDTR flat
	lea eax, [_loader_base]
	add [loader_gdt._bgn_ptr], eax

	ret

; Jump address in EBX
; Clobbers EAX (who cares?)
global goto_pm32
goto_pm32:
	cli ; No IDT yet
	lgdt [loader_gdt]

	mov eax, cr0
	or  eax, 1
	mov cr0, eax

	mov ax, seg_data
	mov ss, ax
	mov ds, ax
	mov es, ax

	push dword seg_code
	push ebx
	o32 retf

; gdt_entry label, base, limit, access+flags
%macro gdt_entry 4
	.%1:
	seg_%1 equ .%1 - ._bgn
	dw %3 & 0xFFFF              ; limit[15:0]
	dw %2 & 0xFFFF              ; base[15:0]
	db %2 >> 16 & 0xFF          ; base[23:16]
	db %4 >>  4 & 0xFF          ; access[7:0]
	%assign flag %4 & 0xF       ; flag[3:0]
	%assign ulim %3 >> 16 & 0xF ; limit[19:16]
	db flag << 4 | ulim         ; {flag, ulim}
	%undef flag
	%undef ulim
	db %2 >> 24 & 0xFF          ; base[31:24]
%endmacro

section .real.data
loader_gdt:
	align 4
	._length:  dw ._end - ._bgn - 1
	._bgn_ptr: dd ._bgn ; + _loader_base
._bgn:
	.null: dq 0
	gdt_entry code,  0, 0xFFFFF, 0b1001_1010_1100
	gdt_entry data,  0, 0xFFFFF, 0b1001_0010_1100
._end:
