bits 16
section .real.text

BPB_TOTAL_SECTS    equ 0x13
BPB_SECTS_PER_CYL  equ 0x18
BPB_HEAD_COUNT     equ 0x1A
BPB_DRIVE_NUMBER   equ 0x24

BPB_RSRVD_COUNT    equ 0x0E
BPB_FAT_COUNT      equ 0x10
BPB_SECTS_PER_CLUS equ 0x0D
BPB_SECTS_PER_FAT  equ 0x16
BPB_ENTRY_COUNT    equ 0x11

struc bpb_data
	.total_sects:    resw 1
	.sects_per_cyl:  resw 1
	.head_count:     resb 1
	.boot_drive_id:  resb 1

	.reserved_count: resw 1
	.fat_count:      resb 1
	.sects_per_clus: resb 1
	.sects_per_fat:  resw 1
	.entry_count:    resw 1
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

	mov bx, bpb_data_size
	call arena_alloc

	push ds
	mov ds, dx

	mov dx, [BPB_TOTAL_SECTS]
	mov [es:bx + bpb_data.total_sects], dx
	mov dx, [BPB_SECTS_PER_CYL]
	mov [es:bx + bpb_data.sects_per_cyl], dx
	mov dl, [BPB_HEAD_COUNT]
	mov[es:bx + bpb_data.head_count], dl
	mov dl, [BPB_DRIVE_NUMBER]
	mov[es:bx + bpb_data.boot_drive_id], dl

	mov dx, [BPB_RSRVD_COUNT]
	mov [es:bx + bpb_data.reserved_count], dx
	mov dl, [BPB_FAT_COUNT]
	mov[es:bx + bpb_data.fat_count], dl
	mov dl, [BPB_SECTS_PER_CLUS]
	mov[es:bx + bpb_data.sects_per_clus], dl
	mov dx, [BPB_SECTS_PER_FAT]
	mov [es:bx + bpb_data.sects_per_fat], dx
	mov dx, [BPB_ENTRY_COUNT]
	mov [es:bx + bpb_data.entry_count], dx

	pop ds
	pop bx
	ret
