bits 16

org 0x0000
stage2:
	xor ah, ah
	mov al, 3
	int 0x10

	mov si, message
	mov cx, -1
	call putsn

	cli
	hlt

; Pointer to string in DS:SI
; Length override in CX
putsn:
	mov ah, 0x0E
	.repeat:
		lodsb
		test al, al
		jz .exit
		int 0x10
	loop .repeat
	.exit:
	ret

message: db "Hello, world!", 0x0D, 0x0A, 0x00
