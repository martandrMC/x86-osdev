bits 32
section .text

global memset
memset:
	push edi
	mov edi, [esp +  8]
	mov eax, [esp + 12]
	mov ecx, [esp + 16]
	rep stosb
	mov eax, [esp +  8]
	pop edi
	ret

global memcpy
memcpy:
	push esi
	push edi
	mov edi, [esp + 12]
	mov esi, [esp + 16]
	mov ecx, [esp + 20]
	rep movsb
	mov eax, [esp + 12]
	pop edi
	pop esi
	ret

global strlen
strlen:
	push edi
	mov edi, [esp + 8]
	xor eax, eax
	xor ecx, ecx
	dec ecx
	repne scasb
	not ecx
	dec ecx
	mov eax, ecx
	pop edi
	ret
