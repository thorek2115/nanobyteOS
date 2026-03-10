; save contents of eax, ecx, edx if important
push y
push x
call _lengthSq
add sp, 4 ; remove arguments (x and y) from the stack

_lengthSq:
    ; create a new call frame
    push bp    ; enter instruction
    mov bp, sp ;

    sub sp, 2 ; ?
    mov ax, [bp + 4] ; first funcion argument x
    mul ax
    mov [bp - 2], ax ; local variable r

    mov ax, [bp + 6] ; second funcion argument x
    mul ax
    add [bp - 2], ax

    mov ax, [bp - 2]

    mov sp, bp ; leave instruction
    pop bp     ; 
    ret

; [bp + 0] => old bp value
; [bp + 2] => return address
; [bp + 4} => x
; [bp + 6] => y
; ...

;   F01E    F020    F022    F024    F024    F026    F028    F02A    F02C
;  |    |  |old bp| |ret |  | x  |  | y  |  |    |  |    |  |    |  |    |
;           ^| bp

;
; optimization:
;
push y
push x
call _lengthSq

_lengthSq:
