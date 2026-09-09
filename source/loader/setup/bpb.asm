bits 16
section .real.text

BPB_TOTAL_SECTS    equ 0x13
BPB_SECTS_PER_TRK  equ 0x18
BPB_HEAD_COUNT     equ 0x1A
BPB_DRIVE_NUMBER   equ 0x24

struc media_info
	.total_sects:    resw 1
	.sects_per_trk:  resw 1
	.head_count:     resb 1
	.boot_drive_id:  resb 1
endstruc

; Heap segment in ES
; BPB segment in DX
; Returns addr in BX
; Clobbers DX
extern arena_alloc
global collect_bpb
collect_bpb:
	xor bx, bx
	call arena_alloc
	push bx

	mov bx, media_info_size
	call arena_alloc

	push ds
	mov ds, dx

	mov dx, [BPB_TOTAL_SECTS]
	mov [es:bx + media_info.total_sects], dx
	mov dx, [BPB_SECTS_PER_TRK]
	mov [es:bx + media_info.sects_per_trk], dx
	mov dl, [BPB_HEAD_COUNT]
	mov[es:bx + media_info.head_count], dl
	mov dl, [BPB_DRIVE_NUMBER]
	mov[es:bx + media_info.boot_drive_id], dl

	pop ds
	pop bx
	ret
