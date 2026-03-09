extern goto_protected
extern goto_unreal

global clear_screen
clear_screen: bits 32
	lea ax, [.um_entry]
	jmp goto_unreal
	.um_entry: bits 16

	xor ah, ah
	mov al, 3
	int 0x10

	lea ax, [.pm_entry]
	jmp goto_protected
	.pm_entry: bits 32

	ret

global put_vga
put_vga: bits 32
	push ebx
	mov ebx, [esp + 8]
	mov ax,  [esp + 12]
	mov [fs:0xB8000 + ebx * 2], ax
	pop ebx
	ret
