; Bootloader.asm
; Compatível com MASM 6.14

.model small
.stack 100h
.code

org 7C00h  ; Define o endereço de origem como 7C00h

start:
    ; Inicialização da pilha
    mov ax, 07C0h
    mov ss, ax
    mov sp, 03FEh

    ; Configuração do segmento de dados
    xor ax, ax
    mov ds, ax

    ; Alterar o modo de vídeo
    mov ah, 00h
    mov al, 03h
    int 10h

    ; Ler dados do disquete (setor 2)
    mov ah, 02h
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0
    mov bx, 0800h
    mov es, bx
    mov bx, 0
    int 13h

    ; Pular para o kernel
    jmp 0800h:0000h

    ; Preencher o restante do setor de boot
    times 510-($-start) db 0
    dw 0xAA55  ; Assinatura de bootloader

end start
