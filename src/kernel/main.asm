org 0x0
bits 16

%define ENDL 0xD, 0xA

start:
    ; prints hello world message
    mov si, msg
    call print

.halt:
    cli
    hlt

;
; Prints a string to the screen
; Parameters:
;   - dx:si points to string
;
print:
    push si
    push ax
.loop:
    lodsb
    cmp al, 0x0
    jz .done
    mov ah, 0x0E
    mov bh, 0x0
    int 0x10
    jmp .loop
.done:
    pop ax
    pop si
    ret

msg: db "Hello World from KERNEL!", ENDL, 0
