; Kernel.asm
; Compatível com MASM 6.14

.model small
.stack 100h
.code

org 0000h  ; Define o endereço de origem como 0000h

start:
    push cs
    pop ds
    call clearscreen

    lea si, Mensagem
    mov ah, 0Eh
repetição:
    mov al, [si]
    cmp al, 0h
    jz terminou
    int 10h
    inc si
    jmp repetição

terminou:
    mov ah, 0h
    int 16h
    mov ax, 0040h
    mov ds, ax
    mov word ptr [0072h], 1234h
    jmp 0FFFFh:0000h

clearscreen proc
    pusha
    mov ah, 06h
    mov al, 0
    mov bh, 0000_1111b
    mov ch, 0
    mov cl, 0
    mov dh, 19h
    mov dl, 50h
    int 10h
    popa
    ret
clearscreen endp

Mensagem db 'Meu primeiro SO', 0

end start
