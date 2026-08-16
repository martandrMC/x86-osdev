bits 16

BPB_DRIVE_NUMBER   equ 0x24
BPB_SECTS_PER_CLUS equ 0x0D
BPB_TOTAL_SECTS    equ 0x13

BPB_RSRVD_COUNT    equ 0x0E
BPB_SECTS_PER_FAT  equ 0x16
BPB_FAT_COUNT      equ 0x10
BPB_ENTRY_COUNT    equ 0x11

BPB_SECTS_PER_CYL  equ 0x18
BPB_HEAD_COUNT     equ 0x1A

BUFFER_SEG equ 0x0060 ; 0x00600 - 0x07BFF used to hold root entries and FAT
BUFFER_MAX equ 59     ; Maximum of 59 sectors = 29.5 kiB (0x7600 bytes)
STAGE2_SEG equ 0x0800 ; 0x08000 - 0x7FFFF used for loading stage two

; ============================================================================ ;

; The first 62 (0x3E) bytes are occupied by the BPB, in
; the beginning of which is contained a jump instruction
; which will direct execution here, skipping the data
org 0x003E
bootsect_entry:
	cli ; Disable interrupts during initial setup

	; Setup the code segment to point to the BPB because later on
	; both DS and ES will be unavailable and we'll need to use CS
	jmp 0x7C0:.start
	.start:

	; Setup the stack to start at 0x7FFF
	; We can safely use up to 0x200 bytes
	xor ax, ax
	mov ss, ax
	mov sp, 0x8000

	sti ; Re-enable interrupts; setup done

	; -------------------------------------------------------------------- ;

	cld ; Ensure string operations increment

	; Save the boot drive ID to read more sectors from later
	mov [BPB_DRIVE_NUMBER], dl

	; Initially setup DS to also point to the BPB in order to
	; save on instruction size when accessing it (no segment override)
	mov ax, cs
	mov ds, ax

	; Setup ES to point to our initial sector buffer
	mov ax, BUFFER_SEG
	mov es, ax

	; If this value is 0 then, per the spec, the partition
	; contains more than 65535 sectors. Our LBA16 would break
	; if that was the case so abort.
	mov ax, [BPB_TOTAL_SECTS]
	test ax, ax
	mov si, err_fsfmt
	jz  boot_failure

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
	shr cx, 4        ; div 2^x same as shift right by x
	cmp cx, BUFFER_MAX
	mov si, err_fsfmt
	ja  boot_failure ; More sectors than we have space for

	mov bx, ax ; Start of root dir ...
	add bx, cx ; plus size of root dir ...
	push bx    ; ... is the start of the data area, save it for later

	; Setup the sector read to deposit data at 0x7E00
	xchg ax, cx   ; We needed AX for the MUL before, for the LBA calc
	call lba_read ; Do the sector read

	; -------------------------------------------------------------------- ;

	mov bx, [BPB_ENTRY_COUNT]
	xor di, di      ; Directory entry at ES:DI
	.search:
	mov al, [es:di]  ; Get first byte of file name
	test al, al      ; Test if it's NUL, marking the end
	mov si, err_found
	jz  boot_failure ; Reached the end without succeeding
	push di
		mov si, signature ; Sample file name string at DS:SI
		mov cx, 12        ; Compare up to 12 chars (Name + Attrs)
		repe cmpsb        ; CISC moment (strncmp)
		jz  .found
	pop di     ; Restore DI (back to the start of the entry)
	add di, 32 ; Advance to the next entry
	dec bx     ; One less entry remaining
	jnz .search
	mov si, err_found
	jmp boot_failure

	; -------------------------------------------------------------------- ;

	.found:
	pop di ; DI held the entry address whose name matched
	mov di, [es:di + 26] ; First cluster number of our file

	; BPB_RSRVD_COUNT tells us how many sectors to skip to go to the FAT
	; Then read BPB_SECTS_PER_FAT sectors (the whole FAT) into our buffer
	mov cx, [BPB_RSRVD_COUNT]
	mov ax, [BPB_SECTS_PER_FAT]
	cmp ax, BUFFER_MAX
	mov si, err_fsfmt
	ja  boot_failure ; More sectors than we have space for
	call lba_read    ; Do the sector read

	; -------------------------------------------------------------------- ;

	mov ax, es
	mov ds, ax         ; Sector buffer with FAT now under DS
	mov ax, STAGE2_SEG ; Prepare new cluster buffer for second stage
	mov es, ax         ; Cluster buffer now on ES for lba_read to use
	.next:

		; Setup and read the next cluster into the buffer
		mov bx, sp      ; Read the TOS into CX, which is the ...
		mov cx, [ss:bx] ; ... start of the data area we had saved
		mov bl, [cs:BPB_SECTS_PER_CLUS]
		xor bh, bh      ; Upcast to 2 bytes
		mov ax, di      ; Get our current cluster
		sub ax, 2       ; First cluster has ID 2 in the FAT
		mul bx          ; DX:AX = AX * BX (Convert to current sector)
		add cx, ax      ; Offset into the data area, amount of sectors
		mov ax, bx      ; Read one cluster from floppy
		push ax         ; Save cluster size for advancement
		call lba_read   ; Do the cluster read
		pop ax

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
	jb  .next

	; Dispose the TOS now that we've loaded the file
	pop ax

	; -------------------------------------------------------------------- ;

	; Setup for transition to stage two
	mov dl, [cs:BPB_DRIVE_NUMBER]
	jmp STAGE2_SEG:0 ; Far-jump to second stage

; ============================================================================ ;

; Message pointer in CS:SI
; Never returns
boot_failure:
	; Restore the correct segment for LODSB
	mov ax, cs
	mov ds, ax

	; BIOS command for printing a character
	mov ah, 0x0E

	.repeat:
		lodsb       ; Load the character into AL
		test al, al ; Check if it's NUL
		jz  .exit   ; If so, we're done
		int 0x10    ; Call the BIOS to print it
	jmp .repeat
	.exit:

	cli
	hlt

; Count of sectors to read in AX
; Data buffer address in ES:0000
; Start LBA in CX
; Clobbers AX, BX, CX, DX, SI
lba_read:
	push es
	xor bx, bx
	.read:
		push ax    ; Save sector count
		push cx    ; Save LBA offset
		mov ax, cx ; Put LBA in AX and do a read
		
		mov si, [cs:BPB_SECTS_PER_CYL]
		xor dx, dx ; Zero the upper half of the dividend
		div si     ; AX div SI -> Q = AX, R = DX
		mov cx, dx ; Remainder was our sector
		inc cx     ; Move to CX and increment

		mov si, [cs:BPB_HEAD_COUNT]
		xor dx, dx ; zero the upper half of the dividend
		div si     ; AX div SI -> Q = AX, R = DX
		; AX was the quotient from before, divide it again
		; to get cylinder in AX and head in DX

		mov ch, al   ; Lower 8 bits of cylinder go to CH
		shl ah, 6    ; Keep only the next two bits of cylinder
		and cl, 0x3F ; Leave out space for those two bits
		or  cl, ah   ; 6 bits of sector with upper 2 bits of cylinder
		mov dh, dl   ; Up to 8 bits for head on DH, DL for drive ID
		mov dl, [cs:BPB_DRIVE_NUMBER]

		mov si, 3
		.retry:
		push si          ; Save attempts counter (some BIOSes clobber SI)
			mov ax, 0x0201
			int 0x13     ; Call the BIOS to read the sector
			jnc .success ; CF=0 means the read succeeded

			xor ax, ax ; Otherwise, the read failed
			int 0x13   ; Reset the disk system
			pop si     ; Restore retries counter ...
			dec si     ; ... and decrement it
			jnz .retry ; Retry if we have attempts remaining

			mov si, err_read ; Otherwise, setup the message ...
			jmp boot_failure ; ... and error out
		.success:
		pop si ; Discard retries counter

		; Advance the segment one sector
		mov ax, es
		add ax, 0x20
		mov es, ax

		pop cx ; Restore LBA offset
		pop ax ; Restore sector count
		inc cx ; Subsequent LBA next time
		dec ax ; One less sector
	jnz .read

	pop es
	ret

; ============================================================================ ;

signature: db "LOADER  SYS", 0x05
err_fsfmt: db "Invalid FS parameters!", 0
err_found: db "Stage 2 not found!", 0
err_read:  db "Disk read error!", 0

; Pad with zeros and append bootable marker
; Total binary should be exactly 450 bytes long
times 448 + $$ - $ db 0
dw 0xAA55
