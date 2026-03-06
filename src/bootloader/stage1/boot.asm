org 0x7C00
bits 16

; CRLF (carriage return line feed)
%define ENDL 0xD, 0xA

;
; FAT12 header
;
jmp short main
nop

bdb_oem:                    db 'BBLFS1.0'       ; Basic BootLoader File System 1.0 (8 bytes, padded with spaces)
bdb_bytes_per_sector:       dw 512              ; 00 02 in hex (little endian) -> 512
bdb_sectors_per_cluster:    db 1                ; 
bdb_reserved_sectors:       dw 1                ;
bdb_fat_count:              db 2                ;
bdb_dir_entries_count:      dw 0xE0             ;
bdb_total_sectors:          dw 2880             ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0xF0             ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                ; 9 sectors per fat
bdb_sectors_per_track:      dw 18               ;
bdb_heads:                  dw 2                ; number of heads or sides on the storage media
bdb_hidden_sectors:         dd 0                ; 
bdb_large_sector_count:     dd 0                ;

; extended boot record
ebr_drive_number:           db 0                        ; 0x00 = floppy, 0x80 = hdd
ebr_reserved:               db 0                        ; reserved
ebr_signature:              db 0x29                     ; 0x28 or 0x29
ebr_volume_id:              db 0x21, 0x37, 0x69, 0x67   ; serial number
ebr_volume_label:           db 'BBL OS     '            ; 11 bytes, padded with spaces
ebr_system_id:              db '67676767'               ; 8 bytes, padded with spaces

main:
    ; setup data segments
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    ; some BIOSes might start at 07C0:0000 instead of 0000:7C00,
    ; make sure we are in the expected location
    push es
    push word .after
    retf
.after:
    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl
    ; mov ax, 1 ; LBA = 1
    ; mov cl, 1 ; 1 sector to read
    ; mov bx, 0x7E00 ; data should be after the bootloader
    ; call disk_read

    ; show loading message
    mov si, msg_loading
    call print

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 0x08
    int 0x13
    jc floppy_error
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    ; note: this section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after
    inc ax                              ; division remainder != 0, add 1
                                        ; this means we have a sector only partially filled with entries
.root_dir_after:
    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx ; clear bx
    mov di, buffer

.search_kernel:
    mov si, file_stage2_bin
    mov cx, 11                          ; compare up to 11 characters
    push di                             ; save di (buffer)

    ; cmpsb - compares two bytes located in memory at addresses ds:si and es:di,
    ; si and di are incremented (when direction flag = 0) or decremented if direction flag=1,
    ; similarly to the cmp instruction - a subtraction is performed and the flags are set
    ; repe - repeat while equal, repeats a string instruction while the operands are equal
    ; (zero flag=1) or until cx reaches 0, cx is decremented each iteration
    repe cmpsb

    pop di ; restore di
    je .found_kernel ; jump if string are equal

    add di, 32 ; move to the next dir entry, add 32 (size of a dir entry)
    inc bx ; increment dir entry checked count
    cmp bx, [bdb_dir_entries_count] ; check if all dir entries are checked
    jl .search_kernel ; jump if there are more entries to check

    jmp kernel_not_found_error ; kernel not found

.found_kernel:
    ; di should have the address to the entry
    mov ax, [di + 26] ; first logical cluster field (offset 26)
    mov [stage2_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors] ; lba address
    mov bx, buffer ; where to store data (buffer)
    mov cl, [bdb_sectors_per_fat] ; number of sectors to read
    mov dl, [ebr_drive_number] ; drive number
    call disk_read

    ; read kernel and process FAT chain
    ; es:bx => KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; read next cluster
    mov ax, [stage2_cluster]
    ; hardcoded value :(
    add ax, 31  ; first cluster = (stage2_cluster - 2) * sectors_per_cluster + start_sector
                ; start sector = reserved + fats + root directory size = 1 + 18 + 14 = 33
    mov cl, 1  ; number of sectors to read
    mov dl, [ebr_drive_number]  ; drive number
    call disk_read

    add bx, [bdb_bytes_per_sector]      ; can overflow if kernel.bin is larger 64KB and corrupt the read file

    ; compute location of next cluster, 
    mov ax, [stage2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx  ; ax = index of entry in FAT, dx = cluster % 2
            ; ax = (stage2_cluster * 3) / 2
    mov si, buffer
    add si, ax  ; buffer + (stage2_cluster * 3) / 2
    mov ax, [ds:si]   ; ax = [buffer + index of the next cluster], read entry from FAT table at index ax

    or dx, dx  ; 1) dx = 1 or 1 => 1      2) dx = 0 or 0 => 0 (ZF)
    jz .even

.odd:
    shr ax, 4 ; shift ax to the right by 4, leave top 12 bits
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF  ; remove 4 top bits (leave 12 bottom), ax and 0b 0000 1111 1111 1111

.next_cluster_after:
    cmp ax, 0x0FF8 ; check if number is above or equal to FF8, which is end of chain
    jae .read_finish

    mov [stage2_cluster], ax
    jmp .load_kernel_loop ; jump to the beginning of the loop

.read_finish:
    ; jump to our kernel
    mov dl, [ebr_drive_number] ; boot device in dl

    ; set segment registers
    mov ax, KERNEL_LOAD_SEGMENT 
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET ; do a far jump

    jmp wait_key_and_reboot             ; should never happen

    cli                                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt

;
; Error handlers
;
floppy_error:
    mov si, msg_read_failed
    call print
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_stage2_not_found
    call print
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0x00
    int 0x16 ; wait for keypress
    jmp 0xFFFF:0000 ; jump to FFFF:0000 (the beginning of BIOS), should reboot

.halt:
    cli
    hlt

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx (bits 0-5): sector number
;   - cx (bits 6-15): cylinder
;   - dh: head
;
lba_to_chs:
    ; preserve ax and dx used in division
    push ax
    push dx

    xor dx, dx ; clear dx register for remainder
    div word [bdb_sectors_per_track] ; dx = sector = (LBA % sectors_per_track) + 1 ; ax = (LBA / sectors_per_track)
    inc dx ; dx = sector number
    mov cx, dx ; cx = sector number
    xor dx, dx ; clear dx register for remainder
    ; head = (LBA / sectors per track) % number_of_heads
    div word [bdb_heads] ; ax = cylinder, dx = head (size dl)
    ; cylinder = (LBA / sectors_per_track) / number_of_heads
    mov dh, dl ; dh = head

    ; expected state:
    ; ax = 98______ 76543210 ; cylinder
    ; cx = 76543210 98CCCCCC ; sector number
    ; register layout:
    ; ax = ______98 76543210 ; cylinder
    ; cx = ________ __CCCCCC ; sector number

    mov ch, al
    ; ax = ______98 76543210 ; cylinder
    ; cx = 76543210 __CCCCCC ; sector number

    shl ah, 6
    ; ax = 98______ 76543210
    ; cx = 76543210 __CCCCCC

    or cl, ah
    ; ax = 98______ 76543210
    ; cx = 76543210 98CCCCCC

    pop ax ; restore ax
    mov dl, al
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up tp 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:
    ; save registers we will modify
    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; temporarily save cl (number of sectors to read)
    call lba_to_chs
    pop ax ; al = number of sectors to read

    mov ah, 0x02 ; read disk sectors

    mov di, 3 ; loop counter
.retry:
    pusha ; save all general purpose reisters
    stc ; set carry flag, some BIOSes don't set it
    int 0x13 ; read disk sectors interrupt with ah=2
    jnc .done ; jump if carry not set

    ; read failed
    popa ; restore all general purpose registers
    call disk_reset

    dec di ; decrement loop counter
    test di, di ; check if di is zero
    jnz .retry ; if it's not zero jump to .retry
.fail:
    jmp floppy_error ; otherwise read failed, jump to floppy error
.done:
    popa ; restore all general purpose registers
    ; restore modified registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
; Resets disk controller
; Parameters:
;   - dl: drive number
;
disk_reset:
    pusha ; save all general purpose reisters
    mov ah, 0x00
    stc ; set the carry flag
    int 0x13 ; disk reset interrupt with ah=0
    jc floppy_error ; jump to floppy error if there is a carry
    popa ; restore all general purpose registers
    ret

;
; Prints a string to the screen
; Parameters:
;   - ds:si points to string
;
print:
    push si
    push ax
    push bx
.loop:
    lodsb
    cmp al, 0x00
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    pop si
    ret

msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_stage2_not_found:   db 'STAGE2.BIN file not found!', ENDL, 0
file_stage2_bin:        db 'STAGE2  BIN'
stage2_cluster:         dw 0

; test: db 0x67, 0x67, 0x67, 0x67, 0x67

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0x0

times 510 - ($ - $$) db 0
dw 0xAA55

buffer:
