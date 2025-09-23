bits 16

BPB_VOLUME_LABEL   equ 0x2B
BPB_SECTS_PER_CLUS equ 0x0D
BPB_TOTAL_SECTS    equ 0x13

BPB_RSRVD_COUNT    equ 0x0E
BPB_SECTS_PER_FAT  equ 0x16
BPB_FAT_COUNT      equ 0x10
BPB_ENTRY_COUNT    equ 0x11

BPB_SECTS_PER_CYL  equ 0x18
BPB_HEAD_COUNT     equ 0x1A

; Sector buffer occupies the majority of the memory under our origin
SECTBUF_SEG equ 0x0060 ; Starts at 0x00600
SECTBUF_SIZ equ 59     ; 59 sectors = 29.5 kiB (0x7600 bytes)
CLUSBUF_SEG equ 0x0800 ; Segment of memory area above boot sector (0x08000)

; ============================================================================ ;

; The first 62 (0x3E) bytes are occupied by the BPB, in
; the beginning of which is contained a jump instruction
; which will direct execution here, skipping the data
org 0x003E
boot_realmode:
	; Setup the code segment to point to the BPB
	jmp 0x7C0:.start
	.start:

	; Initially setup DS to also point to the BPB
	mov ax, cs
	mov ds, ax

	; Setup the stack to occupy 0x07E00 - 0x08000
	mov ax, 0x7E0
	mov ss, ax
	mov sp, 0x200

	; Setup DS to point to our initial sector buffer
	mov ax, SECTBUF_SEG
	mov es, ax

	cld ; Ensure string operations increment

	; -------------------------------------------------------------------- ;

	; If this value is 0 then, per the spec, the partition
	; contains more than 65535 sectors. Our LBA16 would break
	; if that was the case so abort.
	mov ax, [BPB_TOTAL_SECTS]
	test ax, ax
	mov si, err_fsbig
	jz  failure

	; Calculate the base LBA of the Root Directory
	; BPB_SECTS_PER_FAT * BPB_FAT_COUNT + BPB_RSRVD_COUNT
	mov ax, [BPB_SECTS_PER_FAT]
	mov dl, [BPB_FAT_COUNT]
	xor dh, dh ; Upcast to 2 bytes
	mul dx     ; DX:AX = AX * DX
	add ax, [BPB_RSRVD_COUNT]
	; We ignore DX here because we previously ensured
	; the partition is entirely covered using LBA16

	; Calculate the sector count based on the entry count
	; 32 byte entries on 512 byte sectors = 16 per sector
	mov cx, [BPB_ENTRY_COUNT]
	shr cx, 4   ; div 2^x same as shift right by x
	cmp cx, SECTBUF_SIZ
	mov si, err_space
	ja  failure ; More sectors than we have space for

	mov bx, ax ; Start of root dir ...
	add bx, cx ; plus size of root dir ...
	push bx    ; is the start of the data area, save it for later

	; Setup the sector read to deposit data at 0x7E00
	xchg ax, cx    ; We needed AX for the MUL before, for the LBA calc
	xor bx, bx     ; Start of our sector buffer
	call sector_rw ; Do the sector read

	; -------------------------------------------------------------------- ;

	mov bx, [BPB_ENTRY_COUNT]
	xor di, di      ; Directory entry at ES:DI
	.search:
	mov al, [es:di] ; Get first byte of file name
	test al, al     ; Test if it's NUL, marking the end
	mov si, err_found
	jz  failure     ; Reached the end without succeeding
	push di
		mov si, signature ; Sample file name string at DS:SI
		mov cx, 12        ; Compare up to 12 chars (Name + Attrs)
		repe cmpsb        ; CISC moment (strncmp)
		jz  .found
	pop di     ; Restore DI (back to the start of the entry)
	add di, 32 ; Advance to the next entry
	dec bx     ; One less entry remaining
	jnz short .search
	mov si, err_found
	jmp failure

	; -------------------------------------------------------------------- ;

	.found:
	pop di ; DI held the entry address whose name matched
	mov di, [es:di + 26] ; First cluster number of our file

	; BPB_RSRVD_COUNT tells us how many sectors to skip to go to the FAT
	; Then read BPB_SECTS_PER_FAT sectors (the whole FAT) into our buffer
	mov cx, [BPB_RSRVD_COUNT]
	mov ax, [BPB_SECTS_PER_FAT]
	cmp ax, SECTBUF_SIZ
	mov si, err_space
	ja  failure    ; More sectors than we have space for
	xor bx, bx     ; Start of our sector buffer
	call sector_rw ; Do the sector read

	; -------------------------------------------------------------------- ;

	mov ax, es
	mov ds, ax          ; Sector buffer with FAT now under DS
	mov ax, CLUSBUF_SEG ; Prepare new cluster buffer for second stage
	mov es, ax          ; Cluster buffer now on ES for sector_rw to use
	.next:

		; Setup and read the next cluster into the buffer
		mov bx, sp      ; Read the TOS into CX, which is the ...
		mov cx, [ss:bx] ; start of the data area we had saved
		mov bl, [cs:BPB_SECTS_PER_CLUS]
		xor bh, bh      ; Upcast to 2 bytes
		mov ax, di      ; Get our current cluster
		sub ax, 2       ; First cluster has ID 2 in the FAT
		mul bx          ; DX:AX = AX * BX (Convert to current sector)
		add cx, ax      ; Offset into the data area, amount of sectors
		mov ax, bx      ; Read one cluster from floppy (command on AX)
		xor bx, bx      ; Start of our cluster buffer
		call sector_rw  ; Do the cluster read

		; Advance the cluster buffer pointer
		shl ax, 5  ; AH = 0, AL = sectors read, mult by 32
		mov bx, es ; Get our cluster buffer
		add bx, ax ; Increment our segment forward for the next cluster
		mov es, bx

		; Access the FAT to get the next cluster ID
		xor cl, cl    ; Default value of CL is 0
		mov bx, di    ; Get our index into BX
		add bx, di    ; Add our index into BX, now double
		add bx, di    ; Add our index into BX, now triple
		shr bx, 1     ; Divide by two (LSB in CF)
		adc cl, 0     ; Transfer CF to CL (CL = CF ? 1 : 0)
		shl cl, 2     ; Make the 1 case into 4
		mov di, [bx]  ; Fetch the word that contains our entry
		shr di, cl    ; Shift the word down by 4 bits if index was odd
		and di, 0xFFF ; Keep only lower 12 bits

	; Repeat until the end marker was reached
	cmp di, 0xFF8
	jb  short .next

	; -------------------------------------------------------------------- ;

	; Setup the segments for the second stage
	mov ax, CLUSBUF_SEG
	mov ds, ax
	mov es, ax
	jmp CLUSBUF_SEG:0 ; Jump to second stage

; ============================================================================ ;

; Message pointer in CS:SI
; Never returns
failure:
	mov ax, cs
	mov ds, ax       ; Restore the correct segment for LODSB
	mov ah, 0x0E     ; BIOS command for printing a character
	.print:
		lodsb        ; Load the character into AL
		test al, al  ; Check if it's NUL
		jz  .exit    ; Stop looping
		int 0x10     ; Call the BIOS to print it
	jmp short .print ; Repeat
	.exit:
	cli              ; Clear interrupts
	hlt              ; Wait for interrupts (actual halt)

; BPB base in CS
; Command + response in AX
; Data buffer address in ES:BX
; Start LBA in CX
; Clobbers CX and DX
sector_rw:
	push ax    ; Save command
	push bx    ; Save buffer address
	mov ax, cx ; Need LBA in AX

	mov bx, [cs:BPB_SECTS_PER_CYL]
	xor dx, dx ; Zero the upper half of the dividend
	div bx     ; AX div BX -> Q = AX, R = DX

	mov cx, dx ; Remainder was our sector
	inc cx     ; Move to CX and increment

	mov bx, [cs:BPB_HEAD_COUNT]
	xor dx, dx ; zero the upper half of the dividend
	div bx     ; AX div BX -> Q = AX, R = DX
	; AX was the quotient from before, divide it again
	; to get cylinder in AX and head in DX

	mov ch, al   ; Lower 8 bits of cylinder go to CH
	shl ah, 6    ; Keep only the next two bits of cylinder
	and cl, 0x3F ; Leave out space for those two bits
	or  cl, ah   ; 6 bits of sector with upper 2 bits of cylinder
	mov dh, dl   ; Up to 8 bits for head on DH, DL for drive ID

	pop bx ; Restore buffer address
	pop ax ; Restore command

	mov dl, ah   ; Command includes drive ID
	sar dl, 1    ; Keep MSB but remove the LSB
	and dl, 0xBF ; Remove duplicate MSB
	and ah, 1    ; Keep lowest bit of AH as R/W bit
	add ah, 2    ; AH = 2 for Read, AH = 3 for Write

	int 0x13    ; Call BIOS to do disk IO
	mov si, err_read
	jc  failure ; CF=1 means transfer failure
	test ah, ah ; As well as non-zero response code
	jnz failure
	ret

; ============================================================================ ;

signature: db "LOADER  SYS", 0x05
err_fsbig: db "FS too large to be addressed!", 0
err_space: db "Not enough space for FS tables!", 0
err_found: db "Target file not found!", 0
err_read:  db "Disk read error!", 0

; Pad with zeros and append bootable marker
; Total binary should be exactly 512 bytes long
times 448 + $$ - $ db 0
dw 0xAA55
