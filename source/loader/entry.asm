bits 16

LOADER_BASE equ 0x08000

org 0x0000
loader_realmode:
	xor ah, ah
	mov al, 3
	int 0x10

	mov  di, buffer
	xor ebx, ebx
	.next:
		mov ecx, 24
		mov edx, 0x534D4150
		mov eax, 0xE820
		int 0x15
		call print_entry
	test ebx, ebx
	jnz short .next

	cli
	hlt

print_entry:
	push ds
	mov si, es
	mov ds, si

	mov ax, 0x0E20

	lea si, [di + 0]
	call put_hex_qword
	int 0x10
	lea si, [di + 8]
	call put_hex_qword
	int 0x10
	lea si, [di + 16]
	call put_hex_dword
	int 0x10
	lea si, [di + 20]
	call put_hex_dword
	mov al, 0x0D
	int 0x10
	mov al, 0x0A
	int 0x10

	pop ds
	ret

; Byte in AL
; Clobbers AX
put_hex_byte:
	push ax
	shr al, 4
	call .put_nibble
	pop ax
	and al, 0xF
	call .put_nibble
	ret

	.put_nibble:
	cmp al, 9
	jbe short .skip
	add al, 7
	.skip:
	add al, '0'
	mov ah, 0x0E
	int 0x10
	ret

; Word in AX
; Clobbers AX
put_hex_word:
	push ax
	mov al, ah
	call put_hex_byte
	pop ax
	call put_hex_byte
	ret

; DWord pointer in DS:SI
put_hex_dword:
	push ax
	mov ax, [si + 2]
	call put_hex_word
	mov ax, [si + 0]
	call put_hex_word
	pop ax
	ret

; QWord pointer in DS:SI
put_hex_qword:
	push ax
	mov ax, [si + 6]
	call put_hex_word
	mov ax, [si + 4]
	call put_hex_word
	mov ax, [si + 2]
	call put_hex_word
	mov ax, [si + 0]
	call put_hex_word
	pop ax
	ret

buffer:
	.base: dq 0
	.size: dq 0
	.type: dd 0
	.acpi: dd 0
