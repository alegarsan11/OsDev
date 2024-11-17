org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

;
; FAT12 header
;

jmp short start
nop

bdb_oem: db 'MSWIN4.1' ; 8 bytes
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880 ; 2880 * 512 = 1.44MB
bdb_media_descriptor: db 0F0h ; F0 = 3.5" floppy disk
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; extended boot record
ebr_drive_number: db 0 ; 0x00 floppy, 0x80 hard disk
                  db 0 ; reserved
ebr_signature: db 29h
ebr_volume_id: dd 12h, 34h, 56h, 78h
ebr_volume_label: db 'AlexOS    '
ebr_file_system: db 'FAT12   '

start:

	jmp main
; Prints a string to the screen
; PARAMS;
; - ds:si points to string
puts:
	;save registers we will modify
	push si
	push ax

.loop:
	lodsb		; loads next character to al
	or al, al 	; verify if next character is null
	jz .done 	

	mov ah, 0x0e
	mov bh, 0
	int 0x10
	jmp .loop


.done:
	pop ax
	pop si
	ret

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_for_key

wait_for_key:

	mov ah, 0
	int 16h
	jmp 0FFFFh:0

.halt:
	cli
	hlt

main:
	; setup data segments
	mov ax, 0   	; can't writ to ds/es directly
	mov ds, ax
	mov es, ax

	; setup stac
	mov ss, ax
	mov sp, 0x7C00 	; stack grows downwards from where we are loaded in memory
	;read the first sector of the disk
	;bios reads the first sector of the disk into memory at 0x7C00
	mov [ebr_drive_number], dl

	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read

	mov si, msg_hello ; prints the msg
	call puts
	
	hlt

.halt:
	cli 
	hlt

;Disk routines

;Converts an LBA addres to a CHS address
;PARAMS:
; - ax: the logical block address
;RETURNS:
; - cx (bits 6-15): the cylinder
; - dh: the head
; - cx(0-5): the sector

lba_to_chs:

	push ax
	push dx 
	xor dx, dx ;dx = 0
	div word [bdb_sectors_per_track] ; ax = LBA / SPT

	inc dx 
	mov cx, dx	

	xor dx, dx
	div word [bdb_heads]
	
	mov dh, dl
	mov ch, al
	shl ah, 6
	or cl, ah

	pop ax
	mov dl, al
	pop ax
	ret

;Reads a sector from the disk
;PARAMS:
; ax: the logical block address
; es:bx: the buffer to read the sector into
; cl: number of sectors to read
; dl: the drive number
disk_read:

	push ax
	push bx
	push cx
	push dx
	push di

	push cx
	call lba_to_chs
	pop ax
	
	mov ah, 02h
	mov di, 3

.retry:
	pusha
	stc
	int 13h
	jnc .done
	

	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error


.done: 
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc	floppy_error
	popa
	ret


msg_hello: db 'Hello world!',ENDL ,0
msg_read_failed: db 'Failed to read sector',ENDL,0

times 510-($-$$) db 0
dw 0AA55h
