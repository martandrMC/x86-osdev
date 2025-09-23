; gdt_entry label, base, limit, access+flags
%macro gdt_entry 4
	.%1:
	dw %3 & 0xFFFF              ; limit[15:0]
	dw %2 & 0xFFFF              ; base[15:0]
	db %2   >> 16 & 0xFF        ; base[23:16]
	db (%4) >>  4 & 0xFF | 0x80 ; access[7:0] | PRESENT
	%assign flag (%4) & 0xF     ; flag[3:0]
	%assign ulim %3 >> 16 & 0xF ; limit[19:16]
	db flag << 4 | ulim         ; {flag, ulim}
	%undef flag
	%undef ulim
	db %2 >> 24 & 0xFF          ; base[31:24]
%endmacro

; table_begin label
; table_begin label, offset_adjust
%macro table_begin 1-2 0
	%1:
	dw ._end - ._bgn - 1
	dd %2 + ._bgn
	._bgn:
%endmacro

%macro table_end 0
	._end:
%endmacro
