bits 16

section _ENTRY class=CODE

extern _cstart_
global entry

entry:
    cli ; clear interrupt flag
    mov ax, ds ; data segment should be set by stage 1
    mov ss, ax ; copy ds value to ss
    mov sp, 0 ; reset stack pointer
    mov bp, sp
    sti ; set interrupt flag

    ; expect boot drive in dl, send it as argument to cstart function
    xor dh, dh ; clear dh
    push dx ; push dl
    call _cstart_

    cli
    hlt
